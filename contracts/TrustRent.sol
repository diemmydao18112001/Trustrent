// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IBookingNFT {
    function mint(
        address to,
        string calldata tokenURI_
    ) external returns (uint256);
}

/**
 * TrustRent (MVP): ERC-20 stablecoin escrow with monthly release.
 */
contract TrustRent is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant MONTH = 30 days;
    uint256 public constant MIN_START_DELAY = 1 days;
    uint256 public constant MAX_MONTHS = 6;
    uint96 public constant FEE_BPS = 300; // 3%

    IERC20 public immutable paymentToken;
    uint8 public immutable paymentTokenDecimals;
    address public feeReceiver;

    IBookingNFT public bookingNFT;

    uint256 private _listingIdSeq;
    uint256 private _bookingIdSeq;

    // ==== NEW: BNPL & Travel Hooks ==== //

    /// @notice Emitted when a guest expresses intent to use BNPL for an existing booking.
    event BNPLRequested(
        uint256 indexed bookingId,
        address indexed requester,
        uint8 months,
        uint256 amountPlannedUsdCents,
        string plan
    );

    /// @notice Emitted when a user books an off-chain travel package (record-only).
    event TravelPackageBooked(
        uint256 indexed packageId,
        address indexed guest,
        uint256 priceUsdCents
    );

    /// @notice Stored BNPL intent for auditability and future integration.
    struct BNPLRequest {
        address requester; // expected: the booking's guest
        uint8 months; // number of months requested under BNPL
        uint256 amountPlannedUsdCents; // months * priceUsdCentsPerMonth(listing)
        string plan; // e.g., "pay-in-3", "pay-in-4"
        uint256 ts; // timestamp of the intent
    }

    /// @notice Stored last travel booking info per packageId (MVP: single slot).
    struct TravelBooking {
        address guest;
        uint256 priceUsdCents;
        uint256 ts;
    }

    /// @dev History of BNPL requests keyed by bookingId (dynamic list).
    mapping(uint256 => BNPLRequest[]) public bnplRequests;

    /// @dev Latest travel booking keyed by off-chain package id (simple record).
    mapping(uint256 => TravelBooking) public travelBookings;

    struct Listing {
        uint256 id;
        address host;
        uint256 priceUsdCentsPerMonth;
        bool active;
    }

    struct Booking {
        uint256 id;
        uint256 listingId;
        address guest;
        uint256 startTs;
        uint8 monthsTotal;
        uint8 monthsReleased;
        uint256 amountTokenPaid;
        bool cancelled;
        bool disputed;
        uint256 nftId;
    }

    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Booking) public bookings;

    event ListingAdded(
        uint256 indexed listingId,
        address indexed host,
        uint256 priceUsdCentsPerMonth
    );
    event ListingUpdated(
        uint256 indexed listingId,
        uint256 newPriceUsdCentsPerMonth,
        bool active
    );
    event Booked(
        uint256 indexed bookingId,
        uint256 indexed listingId,
        address indexed guest,
        uint256 startTs,
        uint8 months,
        uint256 totalPaid,
        uint256 nftId
    );
    event Released(
        uint256 indexed bookingId,
        uint8 monthsReleasedNow,
        uint256 amountToHost,
        uint256 feeAmount
    );
    event CancelledEarly(
        uint256 indexed bookingId,
        uint8 monthsCompleted,
        uint256 refundToGuest,
        uint256 payoutToHost,
        uint256 feeAmount
    );
    event Disputed(uint256 indexed bookingId, address by);
    event DisputeResolved(
        uint256 indexed bookingId,
        uint256 payoutToHost,
        uint256 payoutToGuest,
        uint256 feeAmount
    );

    error NotHost();
    error NotGuest();
    error NotActive();
    error InvalidArgs();
    error TooEarly();
    error NothingToRelease();
    error AlreadyCancelled();
    error InDispute();

    constructor(address _paymentToken, address _feeReceiver) {
        require(
            _paymentToken != address(0) && _feeReceiver != address(0),
            "ZeroAddress"
        );
        paymentToken = IERC20(_paymentToken);
        paymentTokenDecimals = IERC20Metadata(_paymentToken).decimals();
        feeReceiver = _feeReceiver;
    }

    function setBookingNFT(address nft) external onlyOwner {
        require(nft != address(0), "ZeroAddress");
        bookingNFT = IBookingNFT(nft);
    }

    function setFeeReceiver(address receiver) external onlyOwner {
        require(receiver != address(0), "ZeroAddress");
        feeReceiver = receiver;
    }

    // ========== LISTINGS ==========

    function addListing(
        uint256 priceUsdCentsPerMonth
    ) external returns (uint256) {
        if (priceUsdCentsPerMonth == 0) revert InvalidArgs();
        uint256 id = ++_listingIdSeq;
        listings[id] = Listing({
            id: id,
            host: msg.sender,
            priceUsdCentsPerMonth: priceUsdCentsPerMonth,
            active: true
        });
        emit ListingAdded(id, msg.sender, priceUsdCentsPerMonth);
        return id;
    }

    function updateListing(
        uint256 listingId,
        uint256 newPriceUsdCentsPerMonth,
        bool active
    ) external {
        Listing storage L = listings[listingId];
        if (L.host != msg.sender) revert NotHost();
        if (newPriceUsdCentsPerMonth == 0) revert InvalidArgs();
        L.priceUsdCentsPerMonth = newPriceUsdCentsPerMonth;
        L.active = active;
        emit ListingUpdated(listingId, newPriceUsdCentsPerMonth, active);
    }

    // ========== BOOKINGS ==========

    function book(
        uint256 listingId,
        uint256 startTs,
        uint8 months,
        string calldata tokenURI_
    ) external nonReentrant returns (uint256) {
        Listing memory L = listings[listingId];
        require(L.id != 0, "Listing not found");
        require(L.active, "Listing inactive");
        require(months > 0 && months <= MAX_MONTHS, "Months must be 1-6");
        require(startTs >= block.timestamp + MIN_START_DELAY, "Too early");

        // Check overlap booking
        for (uint256 i = 1; i <= _bookingIdSeq; ) {
            Booking memory existing = bookings[i];
            if (existing.listingId == listingId && !existing.cancelled) {
                uint256 existingEnd = existing.startTs +
                    (existing.monthsTotal * MONTH);
                uint256 newEnd = startTs + (months * MONTH);
                require(
                    newEnd <= existing.startTs || startTs >= existingEnd,
                    "Overlap booking"
                );
            }
            unchecked {
                i++;
            } // saves gas by skipping overflow check
        }

        uint256 perMonthToken = _usdCentsToToken(L.priceUsdCentsPerMonth);
        uint256 total = perMonthToken * months;

        paymentToken.safeTransferFrom(msg.sender, address(this), total);

        uint256 id = ++_bookingIdSeq;
        uint256 nftId = bookingNFT.mint(msg.sender, tokenURI_);
        bookings[id] = Booking({
            id: id,
            listingId: listingId,
            guest: msg.sender,
            startTs: startTs,
            monthsTotal: months,
            monthsReleased: 0,
            amountTokenPaid: total,
            cancelled: false,
            disputed: false,
            nftId: nftId
        });

        emit Booked(id, listingId, msg.sender, startTs, months, total, nftId);
        return id;
    }

    function isAvailable(
        uint256 listingId,
        uint256 startTs,
        uint8 months
    ) public view returns (bool) {
        if (months == 0 || months > MAX_MONTHS) return false;
        Listing memory L = listings[listingId];
        if (L.id == 0 || !L.active) return false;

        for (uint256 i = 1; i <= _bookingIdSeq; i++) {
            Booking memory existing = bookings[i];
            if (existing.listingId == listingId && !existing.cancelled) {
                uint256 existingEnd = existing.startTs +
                    (existing.monthsTotal * MONTH);
                uint256 newEnd = startTs + (months * MONTH);
                if (!(newEnd <= existing.startTs || startTs >= existingEnd)) {
                    return false; // overlap found
                }
            }
        }
        return true;
    }

    function releaseAvailable(uint256 bookingId) external nonReentrant {
        Booking storage B = bookings[bookingId];
        Listing memory L = listings[B.listingId];

        if (msg.sender != L.host) revert NotHost();
        if (B.cancelled) revert AlreadyCancelled();
        if (B.disputed) revert InDispute();

        uint8 monthsCompleted = _monthsCompleted(B.startTs, B.monthsTotal);
        if (monthsCompleted <= B.monthsReleased) revert NothingToRelease();

        uint8 toRelease = monthsCompleted - B.monthsReleased;
        B.monthsReleased = monthsCompleted;

        uint256 perMonthToken = _usdCentsToToken(L.priceUsdCentsPerMonth);
        uint256 gross = perMonthToken * toRelease;
        (uint256 toHost, uint256 fee) = _takeFee(gross);

        paymentToken.safeTransfer(L.host, toHost);
        if (fee > 0) paymentToken.safeTransfer(feeReceiver, fee);

        emit Released(bookingId, toRelease, toHost, fee);
    }

    function cancelEarly(uint256 bookingId) external nonReentrant {
        Booking storage B = bookings[bookingId];
        if (msg.sender != B.guest) revert NotGuest();
        if (B.cancelled) revert AlreadyCancelled();
        if (B.disputed) revert InDispute();

        Listing memory L = listings[B.listingId];

        uint8 monthsCompleted = _monthsCompleted(B.startTs, B.monthsTotal);
        if (monthsCompleted < B.monthsReleased)
            monthsCompleted = B.monthsReleased;

        uint8 completedNotYetReleased = monthsCompleted - B.monthsReleased;
        uint8 monthsRemaining = B.monthsTotal - monthsCompleted;

        uint256 perMonthToken = _usdCentsToToken(L.priceUsdCentsPerMonth);
        uint256 payoutHostGross = perMonthToken * completedNotYetReleased;
        (uint256 payoutHost, uint256 fee1) = _takeFee(payoutHostGross);

        uint256 refundGuest = perMonthToken * monthsRemaining;

        B.monthsReleased = monthsCompleted;
        B.cancelled = true;

        if (payoutHost > 0) paymentToken.safeTransfer(L.host, payoutHost);
        if (refundGuest > 0) paymentToken.safeTransfer(B.guest, refundGuest);
        uint256 feeTotal = fee1;
        if (feeTotal > 0) paymentToken.safeTransfer(feeReceiver, feeTotal);

        emit CancelledEarly(
            bookingId,
            monthsCompleted,
            refundGuest,
            payoutHost,
            feeTotal
        );
    }

    function raiseDispute(uint256 bookingId) external {
        Booking storage B = bookings[bookingId];
        Listing memory L = listings[B.listingId];
        if (msg.sender != B.guest && msg.sender != L.host) revert InvalidArgs();
        if (B.cancelled) revert AlreadyCancelled();
        B.disputed = true;
        emit Disputed(bookingId, msg.sender);
    }

    function resolveDispute(
        uint256 bookingId,
        uint256 payoutToHostGross,
        uint256 payoutToGuest
    ) external onlyOwner nonReentrant {
        Booking storage B = bookings[bookingId];
        Listing memory L = listings[B.listingId];

        uint256 escrowLeft = _escrowLeft(B, L);
        require(
            payoutToHostGross + payoutToGuest <= escrowLeft,
            "Exceed escrow"
        );

        (uint256 toHost, uint256 fee) = _takeFee(payoutToHostGross);

        if (toHost > 0) paymentToken.safeTransfer(L.host, toHost);
        if (payoutToGuest > 0)
            paymentToken.safeTransfer(B.guest, payoutToGuest);
        if (fee > 0) paymentToken.safeTransfer(feeReceiver, fee);

        B.disputed = false;
        emit DisputeResolved(bookingId, toHost, payoutToGuest, fee);
    }

    /// @notice Record an on-chain BNPL intent for an existing booking (no credit check, no disbursement).
    /// @param bookingId Existing booking id
    /// @param months Number of months the guest wishes to spread payments over (must be > 0)
    /// @param plan A human-readable plan label, e.g., "pay-in-3", "pay-in-4"
    function requestBNPL(
        uint256 bookingId,
        uint8 months,
        string calldata plan
    ) external nonReentrant {
        if (months == 0) revert InvalidArgs();

        // Load booking; basic existence guard
        Booking memory b = bookings[bookingId];
        if (b.id == 0) revert InvalidArgs();

        // Restrict to the original guest to avoid spam/abuse
        if (b.guest != msg.sender) revert NotGuest();

        // Compute planned BNPL amount in USD cents (no token conversion here)
        Listing memory L = listings[b.listingId];
        uint256 amountPlannedUsdCents = L.priceUsdCentsPerMonth *
            uint256(months);

        // Persist record
        bnplRequests[bookingId].push(
            BNPLRequest({
                requester: msg.sender,
                months: months,
                amountPlannedUsdCents: amountPlannedUsdCents,
                plan: plan,
                ts: block.timestamp
            })
        );

        // Emit intent for indexers / frontends
        emit BNPLRequested(
            bookingId,
            msg.sender,
            months,
            amountPlannedUsdCents,
            plan
        );
    }

    /// @notice Record an off-chain travel package booking on-chain (for transparency / receipts).
    /// @dev This does not custody funds nor perform any payout.
    /// @param packageId Off-chain package identifier (non-zero)
    /// @param priceUsdCents Quoted package price in USD cents (non-zero)
    function bookTravelPackage(
        uint256 packageId,
        uint256 priceUsdCents
    ) external nonReentrant {
        if (packageId == 0 || priceUsdCents == 0) revert InvalidArgs();

        travelBookings[packageId] = TravelBooking({
            guest: msg.sender,
            priceUsdCents: priceUsdCents,
            ts: block.timestamp
        });

        emit TravelPackageBooked(packageId, msg.sender, priceUsdCents);
    }

    /// @notice Returns the number of BNPL requests recorded for a booking.
    function bnplRequestsCount(
        uint256 bookingId
    ) external view returns (uint256) {
        return bnplRequests[bookingId].length;
    }

    /// @notice Returns a BNPL request by index for a given booking.
    /// @dev Reverts if index is out of bounds.
    function bnplRequestAt(
        uint256 bookingId,
        uint256 index
    )
        external
        view
        returns (
            address requester,
            uint8 months,
            uint256 amountPlannedUsdCents,
            string memory plan,
            uint256 ts
        )
    {
        BNPLRequest storage r = bnplRequests[bookingId][index];
        return (r.requester, r.months, r.amountPlannedUsdCents, r.plan, r.ts);
    }

    // ===== internals =====

    function _usdCentsToToken(
        uint256 usdCents
    ) internal view returns (uint256) {
        unchecked {
            uint256 scale = 10 ** paymentTokenDecimals;
            return (usdCents * scale) / 100;
        }
    }

    function _takeFee(
        uint256 gross
    ) internal pure returns (uint256 net, uint256 fee) {
        fee = (gross * FEE_BPS) / 10000;
        net = gross - fee;
    }

    function _monthsCompleted(
        uint256 startTs,
        uint8 monthsTotal
    ) internal view returns (uint8) {
        if (block.timestamp < startTs) return 0;
        uint256 elapsed = (block.timestamp - startTs) / MONTH;
        uint8 done = uint8(elapsed);
        if (done > monthsTotal) done = monthsTotal;
        return done;
    }

    function _escrowLeft(
        Booking memory B,
        Listing memory L
    ) internal view returns (uint256) {
        uint256 perMonth = _usdCentsToToken(L.priceUsdCentsPerMonth);
        uint256 total = perMonth * B.monthsTotal;

        uint256 releasedGross = perMonth * B.monthsReleased;
        (uint256 releasedNet, uint256 fee_) = _takeFee(releasedGross);
        uint256 spent = releasedNet + fee_;

        if (B.cancelled) {
            uint8 monthsCompleted = _monthsCompleted(B.startTs, B.monthsTotal);
            uint8 monthsRemaining = B.monthsTotal - monthsCompleted;
            spent += perMonth * monthsRemaining;
        }
        if (spent >= total) return 0;
        return total - spent;
    }
}
