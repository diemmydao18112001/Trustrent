require("dotenv").config();
require("@nomicfoundation/hardhat-toolbox");

const pk = (process.env.PRIVATE_KEY || "").trim();
const validPk = /^0x[0-9a-fA-F]{64}$/.test(pk); 

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.9",
    settings: { optimizer: { enabled: true, runs: 200 } }
  },
  networks: {
    hardhat: { chainId: 31337 },
    localhost: { url: "http://127.0.0.1:8545" },
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL || "",
      accounts: validPk ? [pk] : [],  
      chainId: 11155111
    }
  },
  etherscan: {
    apiKey: { sepolia: process.env.ETHERSCAN_API_KEY || "" }
  }
};
