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
            mainnet: process.env.ETH_MAINNET_API_KEY as string,
            core_mainnet: process.env.CORE_MAINNET_API_KEY as string,
            arbitrumOne: process.env.ARBITRUM_MAINNET_API_KEY as string,
            polygon: process.env.POLYGON_MAINNET_API_KEY as string,
        },
        customChains: [
            {
                network: "core_mainnet",
                chainId: 1116,
                urls: {
                    apiURL: "https://openapi.coredao.org/api",
                    browserURL: "https://scan.coredao.org/",
                },
            },
        ],
    },
    networks: {
        // localhost: { url: "http://127.0.0.1:8545", accounts },
        mainnet: { url: process.env.ETH_MAINNET_RPC_URL, accounts },
        core_mainnet: { url: process.env.CORE_MAINNET_RPC_URL, accounts },
        arbitrum: { url: process.env.ARBITRUM_MAINNET_RPC_URL, accounts },
        polygon: { url: process.env.POLYGON_MAINNET_RPC_URL, accounts },
    },

    solidity: { compilers: [{ version: "0.8.20", settings: { optimizer: { enabled: true, runs: 200 } } }] },
};

export default config;
