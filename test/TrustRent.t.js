const { expect } = require("chai");
const { ethers } = require("hardhat");
const DAY = 24 * 60 * 60,
  MONTH = 30 * DAY;

describe("TrustRent MVP", () => {
  let deployer, host, guest, feeReceiver, token, nft, trust;

  beforeEach(async () => {
    [deployer, host, guest, feeReceiver] = await ethers.getSigners();

    const TT = await ethers.getContractFactory("TestToken");
    token = await TT.deploy();
    await token.waitForDeployment();

    const NFT = await ethers.getContractFactory("BookingNFT");
    nft = await NFT.deploy();
    await nft.waitForDeployment();

    const Trust = await ethers.getContractFactory("TrustRent");
    trust = await Trust.deploy(await token.getAddress(), feeReceiver.address);
    await trust.waitForDeployment();

    await (await nft.transferOwnership(await trust.getAddress())).wait();
    await (await trust.setBookingNFT(await nft.getAddress())).wait();

    await token.transfer(guest.address, ethers.parseUnits("10000", 6));
  });

  it("adds listing and books", async () => {
    await expect(trust.connect(host).addListing(80000)).to.emit(
      trust,
      "ListingAdded"
    );
    const now = (await ethers.provider.getBlock("latest")).timestamp;
    const start = now + 2 * DAY;
    const perMonth = (80000n * 10n ** 6n) / 100n;
    const total = perMonth * 2n;
    await token.connect(guest).approve(await trust.getAddress(), total);
    await expect(trust.connect(guest).book(1, start, 2, "ipfs://x")).to.emit(
      trust,
      "Booked"
    );
  });

  it("releases after a month", async () => {
    await trust.connect(host).addListing(80000);
    const now = (await ethers.provider.getBlock("latest")).timestamp;
    const start = now + 2 * DAY;
    const perMonth = (80000n * 10n ** 6n) / 100n;
    const total = perMonth * 2n;
    await token.connect(guest).approve(await trust.getAddress(), total);
    await trust.connect(guest).book(1, start, 2, "");
    await ethers.provider.send("evm_setNextBlockTimestamp", [
      start + MONTH + 10,
    ]);
    await ethers.provider.send("evm_mine", []);
    await expect(trust.connect(host).releaseAvailable(1)).to.emit(
      trust,
      "Released"
    );
  });

  it("allows guest to cancel early and get refund for unused months", async () => {
    await trust.connect(host).addListing(80000);
    const now = (await ethers.provider.getBlock("latest")).timestamp;
    const start = now + 2 * DAY;
    const perMonth = (80000n * 10n ** 6n) / 100n;
    const total = perMonth * 3n;
    await token.connect(guest).approve(await trust.getAddress(), total);
    await trust.connect(guest).book(1, start, 3, "");

    await ethers.provider.send("evm_setNextBlockTimestamp", [
      start + MONTH + 10,
    ]);
    await ethers.provider.send("evm_mine", []);

    const guestBalanceBefore = await token.balanceOf(guest.address);
    await trust.connect(guest).cancelEarly(1);
    const guestBalanceAfter = await token.balanceOf(guest.address);

    expect(guestBalanceAfter).to.be.gt(guestBalanceBefore);
  });

  it("allows admin to resolve dispute by splitting funds", async () => {
    await trust.connect(host).addListing(80000);
    const now = (await ethers.provider.getBlock("latest")).timestamp;
    const start = now + 2 * DAY;
    const perMonth = (80000n * 10n ** 6n) / 100n;
    const total = perMonth * 2n;
    await token.connect(guest).approve(await trust.getAddress(), total);
    await trust.connect(guest).book(1, start, 2, "");

    await trust.connect(guest).raiseDispute(1);
    await trust.resolveDispute(1, perMonth, perMonth);
  });

  it("mints NFT upon booking", async () => {
    await trust.connect(host).addListing(80000);
    const now = (await ethers.provider.getBlock("latest")).timestamp;
    const start = now + 2 * DAY;
    const perMonth = (80000n * 10n ** 6n) / 100n;
    const total = perMonth * 1n;
    await token.connect(guest).approve(await trust.getAddress(), total);
    await trust.connect(guest).book(1, start, 1, "ipfs://metadata");

    expect(await nft.ownerOf(1)).to.equal(guest.address);
  });

  it("emits BNPLRequested when guest requests BNPL plan", async () => {
  await trust.connect(host).addListing(80000);
  const start = (await ethers.provider.getBlock("latest")).timestamp + 2 * DAY;

  // Approve & book
  await token.connect(guest).approve(await trust.getAddress(), ethers.parseUnits("2400", 6));
  await trust.connect(guest).book(1, start, 3, "");

  // Now request BNPL
  await expect(trust.connect(guest).requestBNPL(1, 3, "pay in 3 months"))
    .to.emit(trust, "BNPLRequested")
    .withArgs(1, guest.address, 3, 240000, "pay in 3 months");
});

  it("emits TravelPackageBooked when guest books travel", async () => {
    await expect(trust.connect(guest).bookTravelPackage(101, 50000))
      .to.emit(trust, "TravelPackageBooked")
      .withArgs(101, guest.address, 50000);
  });

  it("still allows BNPL request after booking is cancelled", async () => {
  await trust.connect(host).addListing(80000);
  const start = (await ethers.provider.getBlock("latest")).timestamp + 2 * DAY;
  await token.connect(guest).approve(await trust.getAddress(), ethers.parseUnits("2400", 6));
  await trust.connect(guest).book(1, start, 3, "");

  await trust.connect(guest).cancelEarly(1);

  await expect(trust.connect(guest).requestBNPL(1, 2, "after cancel"))
    .to.emit(trust, "BNPLRequested");
});

it("still allows travel booking after dispute", async () => {
  await trust.connect(host).addListing(80000);
  const start = (await ethers.provider.getBlock("latest")).timestamp + 2 * DAY;
  await token.connect(guest).approve(await trust.getAddress(), ethers.parseUnits("2400", 6));
  await trust.connect(guest).book(1, start, 3, "");

  await trust.connect(guest).raiseDispute(1);

  await expect(trust.connect(guest).bookTravelPackage(202, 50000))
    .to.emit(trust, "TravelPackageBooked");
});

  it("full journey with accommodation, travel, and BNPL request", async () => {
    const now = (await ethers.provider.getBlock("latest")).timestamp;

    // Host lists accommodation
    await trust.connect(host).addListing(80000);

    // Guest books accommodation for 2 months
    const start = now + 2 * DAY;
    const perMonthToken = (80000n * 10n ** 6n) / 100n;
    const totalToken = perMonthToken * 2n;
    await token.connect(guest).approve(await trust.getAddress(), totalToken);
    await trust.connect(guest).book(1, start, 2, "ipfs://metadata");

    // Guest books a travel package
    await expect(trust.connect(guest).bookTravelPackage(501, 120000))
      .to.emit(trust, "TravelPackageBooked")
      .withArgs(501, guest.address, 120000);

    // Guest requests BNPL plan
    await expect(
      trust.connect(guest).requestBNPL(1, 2, "pay half now, half later")
    )
      .to.emit(trust, "BNPLRequested")
      .withArgs(1, guest.address, 2, 160000, "pay half now, half later");

    // Move time forward to allow first month release
    await ethers.provider.send("evm_setNextBlockTimestamp", [
      start + MONTH + 10,
    ]);
    await ethers.provider.send("evm_mine", []);
    await trust.connect(host).releaseAvailable(1);

    // Guest cancels early
    await trust.connect(guest).cancelEarly(1);

    // NFT proof still valid
    expect(await nft.ownerOf(1)).to.equal(guest.address);
  });

  it("rejects overlapping bookings", async () => {
    await trust.connect(host).addListing(80000);
    const start =
      (await ethers.provider.getBlock("latest")).timestamp + 2 * 24 * 60 * 60;
    await token
      .connect(guest)
      .approve(await trust.getAddress(), ethers.parseUnits("2400", 6));
    await trust.connect(guest).book(1, start, 2, "");

    await token
      .connect(guest)
      .approve(await trust.getAddress(), ethers.parseUnits("800", 6));
    await expect(
      trust.connect(guest).book(1, start + 24 * 60 * 60, 1, "")
    ).to.be.revertedWith("Overlap booking");
  });

  it("allows bookings with overlapping dates but different listings", async () => {
  await trust.connect(host).addListing(80000); // Listing 1
  await trust.connect(host).addListing(90000); // Listing 2

  const start = (await ethers.provider.getBlock("latest")).timestamp + 2 * DAY;

  // Booking for listing 1
  await token.connect(guest).approve(await trust.getAddress(), ethers.parseUnits("1600", 6));
  await trust.connect(guest).book(1, start, 2, "");

  // Booking for listing 2 with overlapping time should pass
  await token.connect(guest).approve(await trust.getAddress(), ethers.parseUnits("1800", 6));
  await expect(trust.connect(guest).book(2, start + DAY, 2, "")).to.not.be.reverted;
});

  it("reverts dispute resolution if over escrow", async () => {
    await trust.connect(host).addListing(80000);
    const start =
      (await ethers.provider.getBlock("latest")).timestamp + 2 * 24 * 60 * 60;
    await token
      .connect(guest)
      .approve(await trust.getAddress(), ethers.parseUnits("2400", 6));
    await trust.connect(guest).book(1, start, 3, "");

    await trust.connect(guest).raiseDispute(1);
    await expect(
      trust.resolveDispute(
        1,
        ethers.parseUnits("5000", 6),
        ethers.parseUnits("5000", 6)
      )
    ).to.be.revertedWith("Exceed escrow");
  });

  it("stores correct NFT metadata URI", async () => {
    await trust.connect(host).addListing(80000);
    const start =
      (await ethers.provider.getBlock("latest")).timestamp + 2 * 24 * 60 * 60;
    await token
      .connect(guest)
      .approve(await trust.getAddress(), ethers.parseUnits("800", 6));
    await trust.connect(guest).book(1, start, 1, "ipfs://metadata-test");
    expect(await nft.tokenURI(1)).to.equal("ipfs://metadata-test");
  });
it("isAvailable returns false when booking overlaps", async () => {
  await trust.connect(host).addListing(80000);
  const now = (await ethers.provider.getBlock("latest")).timestamp;
  const start = now + 2 * DAY;

  // Approve and book listing 1 for 2 months
  await token.connect(guest).approve(await trust.getAddress(), ethers.parseUnits("1600", 6));
  await trust.connect(guest).book(1, start, 2, "");

  // Check availability should be false if overlapping
  const available = await trust.isAvailable(1, start + DAY, 1);
  expect(available).to.equal(false);
});

it("isAvailable returns true for a different listing or non-overlapping dates", async () => {
  await trust.connect(host).addListing(80000); // listing 1
  await trust.connect(host).addListing(90000); // listing 2
  const now = (await ethers.provider.getBlock("latest")).timestamp;
  const start = now + 2 * DAY;

  // Book listing 1
  await token.connect(guest).approve(await trust.getAddress(), ethers.parseUnits("1600", 6));
  await trust.connect(guest).book(1, start, 2, "");

  // Check availability for listing 2 with same time 
  const diffListingAvail = await trust.isAvailable(2, start, 2);
  expect(diffListingAvail).to.equal(true);

  // Check availability for listing 1 but after existing booking 
  const afterEnd = start + 2 * MONTH + DAY;
  const noOverlapAvail = await trust.isAvailable(1, afterEnd, 1);
  expect(noOverlapAvail).to.equal(true);
});
});
