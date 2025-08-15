// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/** Simple mintable ERC20 for local testing (6 decimals like USDC). */
contract TestToken is ERC20 {
    constructor() ERC20("Test USD Coin", "tUSDC") {
        _mint(msg.sender, 1_000_000_000 * 10**6);
    }
    function decimals() public pure override returns (uint8) { return 6; }
}