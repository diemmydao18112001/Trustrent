# TrustRent – Decentralized Mid-Term Rental Platform

## Overview
TrustRent is a blockchain-based escrow protocol for mid-term rentals (1–6 months), designed for crypto-native users seeking transparent, low-fee alternatives to centralized rental platforms.

The platform ensures that rental payments are securely held in escrow and released monthly to hosts, with built-in early termination refunds, dispute resolution, and NFT proof-of-booking. The MVP also includes Travel Package Booking and a Buy Now Pay Later (BNPL) request event as a placeholder for future integration with decentralised credit scoring.


## Contents
- **Contracts**
  - Solidity smart contracts: `TrustRent`, `BookingNFT`, `TestToken`, mocks
- **Scripts**
  - Deployment scripts for localhost & Sepolia
- **Tests**
  - Hardhat tests (16 total, all passing)
- **Addresses**
  - Deployment addresses for localhost and Sepolia

---

## Key Features

1. **Escrow Logic**  
   Tenant funds are held in the contract and released per 30-day epoch.  
   Funds are denominated in ERC-20 stablecoins (mock USDC-like `TestToken` in MVP).

2. **Early Termination & Refunds**  
   Guests can terminate early and receive a refund for unused months. Refund calculation is automatic and verifiable on-chain.

3. **Dispute Resolution**  
   Admin can split the remaining escrow between the host and guest upon dispute. Ensures fair handling of service failures or unexpected circumstances.

4. **NFT Proof-of-Booking**  
   Each confirmed booking mints an ERC-721 NFT as immutable proof of transaction.
   Metadata includes booking details, enabling on-chain verifiability.

6. **Travel Package Add-On**  
   An optional module for guests to purchase a travel package alongside accommodation.
   Recorded as part of the booking transaction for transparency.

8. **BNPL Request Event (Future Integration)**  
   Guests can emit a `BNPLRequested` event when seeking deferred payment terms.
   In the MVP, this is a conceptual hook — no credit logic implemented.
   Roadmap includes integration with decentralised credit scoring oracles and stablecoin lending pools.

---

## Technical Architecture

**Smart Contracts**  
   TrustRent.sol – Core escrow, booking, dispute, travel add-on, BNPL event. 
   BookingNFT.sol – ERC-721 implementation for booking receipts. 
   TestToken.sol – Mock ERC-20 stablecoin (6 decimals, USDC-like). 
   MockV3Aggregator.sol – Mock Chainlink price feed for testing.

**Testing**  
  Implemented with Hardhat’s testing suite. 
  Covers booking lifecycle, refunds, disputes, NFT metadata, travel add-ons, and BNPL events. 
  All 16 tests pass on local and Sepolia testnet.

--- 

## Current Sepolia Deployment (Verified on Etherscan) 
**TrustRent**
[0x96aB993BF36bFf2aEED62BDf30564B939e5d2156] (https://sepolia.etherscan.io/address/0x96aB993BF36bFf2aEED62BDf30564B939e5d2156#code) 

**BookingNFT**
[0x997bce0B6742E849bb52acCbbD96eA8Ad52908B3](https://sepolia.etherscan.io/address/0x997bce0B6742E849bb52acCbbD96eA8Ad52908B3#code)

**TestToken** 
[0xE1293B5F36Ab7D759252Ef4a3413Be194460bdEa](https://sepolia.etherscan.io/address/0xE1293B5F36Ab7D759252Ef4a3413Be194460bdEa#code)


## Buy Now Pay Later
**1. Strategic Rationale**
The incorporation of a Buy Now Pay Later (BNPL) mechanism follows the industry trend of embedding payment flexibility directly into rental transactions. In the context of mid-term rental markets, BNPL can serve as a liquidity bridge for tenants, particularly digital nomads and early-career professionals, without resorting to high-cost short-term credit. From a platform competitiveness perspective, BNPL differentiates TrustRent from incumbent rental portals (Airbnb, Booking) by enabling crypto-native deferred settlement, thus directly responding to the judge’s feedback about exploring disruptive payment models.


**2. MVP Constraints and Design Choice**
While full BNPL implementation necessitates credit risk assessment, regulatory compliance under consumer credit law, and fraud prevention, these were intentionally excluded from the MVP due to:
Scope & Timeframe– Hackathon and dissertation timelines preclude integration of live credit bureau APIs (e.g., Experian, Equifax).
Regulatory Complexity – UK/EU BNPL regulation is converging towards stricter affordability checks; integrating prematurely risks non-compliance.

Blockchain Determinism – On-chain execution cannot inherently access off-chain credit data without oracles, which introduces latency and trust dependencies.

Instead, the MVP implements a BNPL request event (BNPLRequested) as a scaffold for future integration. This approach demonstrates technical foresight while avoiding scope creep, ensuring the dissertation reflects a viable, staged development pathway.

**3. Regulatory and Risk Considerations**
BNPL in crypto requires compliance with evolving jurisdictional rules, consumer protection, and AML/KYC standards. These will be embedded in future phases via geo-restricted smart contracts and on-chain KYC.


**4. Roadmap for TrustRent BNPL Deployment**
Phase 1 (MVP) BNPL request event + logging in TrustRent.sol: Demonstrates architecture extensibility

Phase 2 Oracle-based credit score verification; off-chain data bridging: Operationalises the academic concept of embedded credit scoring

Phase 3 Liquidity pool funding with stablecoin pre-settlement to host: Achieves functional parity with traditional BNPL in a decentralised context

Phase 4 Regulatory compliance automation (smart disclosures, geo-restrictions): Future-proofs the protocol against legislative tightening


