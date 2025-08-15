const { ethers } = require("hardhat");

async function main() {
  const trustRentAddress = "0x96aB993BF36bFf2aEED62BDf30564B939e5d2156";

  const abi = [
    "function requestBNPL(uint256 bookingId, uint256 months, string memory terms) public",
  ];

  const [signer] = await ethers.getSigners();
  console.log("Using account:", signer.address);

  const trustRent = new ethers.Contract(trustRentAddress, abi, signer);

  const tx = await trustRent.requestBNPL(1, 3, "pay in 3 months");
  console.log("Transaction sent:", tx.hash);

  await tx.wait();
  console.log("BNPLRequested event emitted!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
