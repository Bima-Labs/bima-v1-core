import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-chai-matchers";
import "@typechain/hardhat";
import "solidity-coverage";
import "dotenv";
import "hardhat-deploy";
import "@midl-xyz/hardhat-deploy";
import "tsconfig-paths/register";
import type { HardhatUserConfig } from "hardhat/config";
import { resolve } from "path";
import { config as dotenvConfig } from "dotenv";
import { MempoolSpaceProvider } from "@midl-xyz/midl-js-core";

dotenvConfig({ path: resolve(__dirname, "./.env") });

const walletsPaths = {
    leather: "m/86'/1'/0'/0/0",
};

const accounts = [process.env.MNEMONIC as string];

const config: HardhatUserConfig & { midl: any } = {
    networks: {
        default: {
            url: "https://rpc.regtest.midl.xyz",
            accounts: {
                mnemonic: process.env.MNEMONIC,
                path: walletsPaths.leather,
            },
            chainId: 777,
        },
    },
    midl: {
        path: "newdeployments",
        networks: {
            default: {
                mnemonic: accounts[0],
                confirmationsRequired: 1,
                btcConfirmationsRequired: 1,
                hardhatNetwork: "default",
                network: {
                    explorerUrl: "https://mempool.regtest.midl.xyz",
                    id: "regtest",
                    network: "regtest",
                },
                provider: new MempoolSpaceProvider({
                    regtest: "https://mempool.regtest.midl.xyz",
                } as any),
            },
        },
    },
    solidity: {
        compilers: [
            {
                version: "0.8.20",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
        ],
    },
};

export default config;
