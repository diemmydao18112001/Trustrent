const { ethers } = require("hardhat");
const fs = require("fs");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  const networkName = hre.network.name;
  console.log("Network:", networkName);

  // 1. Deploy BookingNFT
  const BookingNFT = await ethers.getContractFactory("BookingNFT");
  const bookingNFT = await BookingNFT.deploy();
  await bookingNFT.waitForDeployment();
  const bookingNFTAddr = await bookingNFT.getAddress();
  console.log("BookingNFT deployed at:", bookingNFTAddr);

  // 2. Deploy TestToken 
  const TestToken = await ethers.getContractFactory("TestToken");
  const testToken = await TestToken.deploy();
  await testToken.waitForDeployment();
  const testTokenAddr = await testToken.getAddress();
  console.log("TestToken deployed at:", testTokenAddr);

  // 3. Deploy Mock Price Feed (8 decimals, $1.00)
  const MockV3 = await ethers.getContractFactory("MockV3Aggregator");
  const mock = await MockV3.deploy(8, 100000000); // 1.00000000
  await mock.waitForDeployment();
  const mockAddr = await mock.getAddress();
  console.log("Mock price feed deployed at:", mockAddr);

  // 4. Deploy TrustRent
  const TrustRent = await ethers.getContractFactory("TrustRent");
  const trustRent = await TrustRent.deploy(testTokenAddr, mockAddr);
  await trustRent.waitForDeployment();
  const trustRentAddr = await trustRent.getAddress();
  console.log("TrustRent deployed at:", trustRentAddr);

  // 5. Save addresses.json
  const addresses = {
    BookingNFT: bookingNFTAddr,
    TestToken: testTokenAddr,
    MockPriceFeed: mockAddr,
    TrustRent: trustRentAddr
  };
  fs.writeFileSync(`addresses.${networkName}.json`, JSON.stringify(addresses, null, 2));
  console.log(`Addresses saved to addresses.${networkName}.json`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
