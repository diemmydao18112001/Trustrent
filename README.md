# TrustRent — Smart-Contract Escrow for Mid-Term Rentals

TrustRent is a fintech prototype exploring how smart contracts could support transparent payment flows for mid-term rentals of one to six months.

The system uses ERC-20 escrow to hold tenant funds, release payments to hosts in monthly stages, calculate early-termination refunds, support dispute allocation and issue ERC-721 booking receipts.

> **MVP status:** The smart-contract prototype was deployed and verified on Ethereum Sepolia. A wallet-integrated Web3 frontend was outside the final delivered scope; the working on-chain flow is reproducible through Etherscan.

## Business Problem

Large rental platforms provide reach and convenience but can involve high platform fees, limited transparency around payment flows and opaque dispute-resolution processes.

TrustRent explores an alternative model focused on:

- Transparent escrow and staged host payments
- Lower and traceable platform fees
- Rules-based early-termination refunds
- Auditable dispute payouts
- Verifiable proof of booking

## My Contribution

I led the smart-contract workstream and was responsible for:

- Designing and implementing the core escrow and payment logic in `TrustRent.sol`
- Building the ERC-721 booking receipt in `BookingNFT.sol`
- Creating a six-decimal USDC-like test token in `TestToken.sol`
- Implementing monthly releases, early-termination refunds and dispute payout logic
- Applying a 3% platform fee only to the host payout leg
- Identifying and resolving timestamp and integer-rounding edge cases
- Developing Hardhat tests across booking, release, refund, dispute, overlap, NFT and BNPL-event scenarios
- Deploying and verifying the contracts on Ethereum Sepolia
- Creating a reproducible Etherscan runbook for the approve-to-book flow
- Connecting technical design decisions with business-model, risk, governance and regulatory considerations

## Core MVP Features

### ERC-20 Escrow

Tenant funds are transferred into the smart contract at booking and held in escrow.

The prototype uses a six-decimal test token designed to behave similarly to USDC.

### Monthly Host Payments

Payments are released to the host in monthly stages rather than as a single upfront payout.

### Early-Termination Refunds

When a tenant cancels early, the contract calculates:

- The host payment for completed months
- The refund for unused months
- The platform fee on the host payout only

Guest refunds are not charged a platform fee.

### Dispute Resolution

An administrator can allocate the remaining escrow between the host and guest.

The contract validates that the combined payouts do not exceed the escrow balance and emits an auditable dispute event.

### NFT Proof of Booking

A successful booking mints an ERC-721 receipt containing the booking reference and rental period.

No personal customer information is stored in the NFT metadata.

## Fee Model

The platform fee is configured as:

```solidity
FEE_BPS = 300;
```

This represents a 3% fee.

The fee is charged only when funds are paid to the host through the release, cancellation or dispute flows. It is not charged when the guest deposits funds, and guest refunds are not fee-bearing.

## Technical Stack

- Solidity
- Hardhat
- JavaScript
- OpenZeppelin Contracts
- ERC-20
- ERC-721
- Ethereum Sepolia
- Etherscan

Security-related patterns used in the MVP include:

- `ReentrancyGuard`
- `SafeERC20`
- Checks–Effects–Interactions on key payout flows
- Explicit validation for timing, overlapping bookings and escrow limits

## Testing and Evidence
All 16 Hardhat tests pass locally.
The project includes a Hardhat test suite covering:

- Booking deposits
- Monthly releases
- Early cancellations and refunds
- Dispute allocations
- Overlapping-booking validation
- NFT minting and metadata
- BNPL request events
- Timing and token-conversion edge cases

The contracts were deployed and verified on Ethereum Sepolia, where the following behaviour was demonstrated through Etherscan:

1. Approving the TrustRent contract to spend the test token
2. Creating a valid booking
3. Verifying the emitted `Booked` event
4. Confirming NFT ownership through `ownerOf`
5. Confirming NFT metadata through `tokenURI`
6. Reproducing the `Too early` validation error for an invalid start time

## Sepolia Deployment

| Contract | Address |
|---|---|
| TrustRent | [`0x96aB993BF36bFf2aEED62BDf30564B939e5d2156`](https://sepolia.etherscan.io/address/0x96aB993BF36bFf2aEED62BDf30564B939e5d2156#code) |
| BookingNFT | [`0x997bce0B6742E849bb52acCbbD96eA8Ad52908B3`](https://sepolia.etherscan.io/address/0x997bce0B6742E849bb52acCbbD96eA8Ad52908B3#code) |
| TestToken | [`0xE1293B5F36Ab7D759252Ef4a3413Be194460bdEa`](https://sepolia.etherscan.io/address/0xE1293B5F36Ab7D759252Ef4a3413Be194460bdEa#code) |

Deployment metadata is also available in:

- `addresses.localhost.json`
- `addresses.sepolia.json`

## BNPL Exploration

BNPL was considered as a possible way to reduce the upfront payment burden for tenants.

For the MVP, it was deliberately limited to a `BNPLRequested` event:

- No credit is issued
- No funds are advanced
- The escrow rules are unchanged
- Credit scoring, affordability checks, liquidity and regulatory compliance remain outside the MVP scope

A future product version would require integration with an appropriately regulated payment or electronic-money partner rather than implementing credit directly within the prototype.

## Additional Experimentation

A travel-package add-on was explored as an optional extension to the booking flow.

It is not part of the core escrow value proposition and is retained as an example of how additional services could be recorded alongside a rental booking.

## Known Limitations

The current MVP has several known limitations:

- No wallet-integrated Web3 frontend
- Centralised administrator role for dispute resolution
- Booking overlap checks are not optimised for scale
- BNPL is an intent event rather than a credit product
- `book()` should be reordered to follow strict Checks–Effects–Interactions
- Dispute resolution should update the booking state more comprehensively
- Functional tests should be extended with property and invariant testing

## Planned Improvements

Potential next steps include:

- Build a React or Next.js wallet interface
- Add invariant tests for fee conservation and escrow non-underflow
- Move administrative permissions to a multisig and timelock
- Introduce an independent arbitrator interface
- Add an anyone-can-release mechanism after the payment due date
- Improve booking-overlap checks for larger-scale use
- Integrate a regulated payments partner for production pay-in and payout flows

## Run Locally

Requirements:

- Node.js 22 or later
- npm

Install dependencies:

```bash
npm ci
```

Compile the contracts:

```bash
npx hardhat compile
```

Run the test suite:

```bash
npx hardhat test
```

The project was most recently tested with Node.js `v24.18.0`.

## Repository Structure

```text
contracts/                 Solidity contracts
scripts/                   Deployment and configuration scripts
test/                      Hardhat tests
addresses.localhost.json   Local deployment addresses
addresses.sepolia.json     Sepolia deployment addresses
hardhat.config.js          Hardhat configuration
package.json               Dependencies and scripts
package-lock.json          Reproducible dependency versions
```

## Academic Context

TrustRent was developed as part of the MSc Financial Technology Hackathon Project at the University of Exeter Business School.