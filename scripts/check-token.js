const { ethers } = require("hardhat");
async function main(){
  const tokenAddr = process.env.PAYMENT_TOKEN;
  console.log("PAYMENT_TOKEN:", tokenAddr);
  const code = await ethers.provider.getCode(tokenAddr);
  console.log("Has code?", code && code !== "0x");
  const abi = [{"inputs":[],"name":"decimals","outputs":[{"internalType":"uint8","name":"","type":"uint8"}],"stateMutability":"view","type":"function"}];
  const erc20 = new ethers.Contract(tokenAddr, abi, ethers.provider);
  console.log("decimals:", await erc20.decimals());
}
main().catch(e=>{console.error(e);process.exit(1);});
