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
            hemi: "not_required",
            plume: "not_required",
            sonic: process.env.SONIC_MAINNET_API_KEY as string,
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
            {
                network: "hemi",
                chainId: 43111,
                urls: {
                    apiURL: "https://explorer.hemi.xyz/api",
                    browserURL: "https://explorer.hemi.xyz",
                },
            },
            {
                network: "plume",
                chainId: 98866,
                urls: {
                    apiURL: "https://explorer.plume.org/api\?",
                    browserURL: "https://explorer.plume.org",
                },
            },
            {
                network: "sonic",
                chainId: 146,
                urls: {
                    apiURL: "https://api.sonicscan.org/api",
                    browserURL: "https://sonicscan.org",
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
        hemi: { url: "https://rpc.hemi.network/rpc", accounts },
        plume: { url: "https://rpc.plume.org", accounts },
        sonic: { url: "https://rpc.soniclabs.com", accounts },
    },

    solidity: { compilers: [{ version: "0.8.20", settings: { optimizer: { enabled: true, runs: 200 } } }] },
};

export default config;
