const hre = require("hardhat");

async function main() {
  const BookingNFT = await hre.ethers.getContractFactory("BookingNFT");
  const bookingNFT = await BookingNFT.deploy(); // deploy

  await bookingNFT.waitForDeployment(); 

  console.log("BookingNFT deployed to:", await bookingNFT.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
