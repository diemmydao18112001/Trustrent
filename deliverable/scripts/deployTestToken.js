const { ethers } = require("hardhat");

async function main() {
  console.log("Booting deployTestToken.js...");
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  const TT = await ethers.getContractFactory("TestToken");
  const tt = await TT.deploy();
  await tt.waitForDeployment();
  console.log("TestToken on Sepolia:", await tt.getAddress());
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
