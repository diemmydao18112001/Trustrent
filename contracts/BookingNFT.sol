// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * BookingNFT: one NFT per successful booking.
 * Only the TrustRent contract (owner) can mint.
 */
contract BookingNFT is ERC721URIStorage, Ownable {
    uint256 private _id;

    constructor() ERC721("TrustRent Booking", "TRBOOK") {}

    function mint(address to, string memory tokenURI_) external onlyOwner returns (uint256) {
        uint256 tokenId = ++_id;
        _safeMint(to, tokenId);
        if (bytes(tokenURI_).length > 0) {
            _setTokenURI(tokenId, tokenURI_);
        }
        return tokenId;
    }

    function lastId() external view returns (uint256) {
        return _id;
    }
}