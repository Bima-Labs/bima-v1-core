import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@typechain/hardhat";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-chai-matchers";
import "dotenv/config";
import "@nomicfoundation/hardhat-verify";

require("@nomicfoundation/hardhat-foundry");

const accounts = process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [];

const config: HardhatUserConfig = {
    defaultNetwork: "localhost",
    etherscan: {
        apiKey: {
            eth_mainnet: process.env.ETH_MAINNET_API_KEY as string,
        },
        customChains: [],
    },
    networks: {
        localhost: { url: "http://127.0.0.1:8545", accounts },
        eth_mainnet: { url: process.env.ETH_MAINNET_RPC_URL, accounts },
    },
    solidity: { compilers: [{ version: "0.8.19", settings: { optimizer: { enabled: true, runs: 200 } } }] },
};

export default config;
