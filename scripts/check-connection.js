const { ethers } = require("hardhat");
async function main(){
  console.log("RPC set?", !!process.env.SEPOLIA_RPC_URL);
  const net = await ethers.provider.getNetwork();
  console.log("Chain:", net.chainId.toString());
  const block = await ethers.provider.getBlockNumber();
  console.log("Block:", block);
  const signers = await ethers.getSigners();
  console.log("Signers:", signers.length, signers[0]?.address || "NO_SIGNER");
}
main().catch(e=>{console.error(e);process.exit(1);});
