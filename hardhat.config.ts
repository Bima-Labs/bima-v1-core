import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@typechain/hardhat";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-chai-matchers";
import "dotenv/config";

const config: HardhatUserConfig = {
  // defaultNetwork: "polygon_amoy",

  etherscan: {
    apiKey: {
      lorenzo_testnet: "",
      citrea_devnet: "",
      base_sepolia_testnet: "",
      linea_sepolia_testnet: "",
      bevm_testnet: "",
      avalanche_testnet: "",
    },
    customChains: [
      {
        network: "lorenzo_testnet",
        chainId: 83291,

        urls: {
          browserURL: "https://scan-testnet.lorenzo-protocol.xyz/",
          apiURL: "https://scan-testnet.lorenzo-protocol.xyz/api/",
        },
      },
      {
        network: "bevm_testnet",
        chainId: 11503,

        urls: {
          browserURL: "https://scan-testnet.bevm.io/",
          apiURL: "https://scan-testnet-api.bevm.io/api/v2/",
        },
      },
      {
        network: "linea_sepolia_testnet",
        chainId: 59141,

        urls: {
          browserURL: "https://sepolia.lineascan.build/",
          apiURL: "https://api-sepolia.lineascan.build/api",
        },
      },
      {
        network: "base_sepolia_testnet",
        chainId: 84532,

        urls: {
          browserURL: "https://sepolia.basescan.org/",
          apiURL: "https://api-sepolia.basescan.org/api",
        },
      },
      {
        network: "citrea_devnet",
        chainId: 62298,

        urls: {
          browserURL: "https://explorer.devnet.citrea.xyz/",
          apiURL: "https://explorer.devnet.citrea.xyz/api/",
        },
      },
      {
        network: "avalanche_testnet",
        chainId: 43113,

        urls: {
          browserURL: "https://43113.testnet.snowtrace.io/",
          apiURL: "https://api.routescan.io/v2/network/testnet/evm/43113/etherscan/api",
        },
      },
    ],
  },
  networks: {
    lorenzo_testnet: {
      url: "https://rpc-testnet.lorenzo-protocol.xyz",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    bevm_testnet: {
      url: "https://testnet.bevm.io",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    linea_sepolia_testnet: {
      url: "https://linea-sepolia.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    base_sepolia_testnet: {
      url: "https://sepolia.base.org",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    polygon_amoy: {
      url: "https://rpc-amoy.polygon.technology",
      accounts: ["7c5b27c4f043051e405d03469e3f9dfe5b65df74376dcaf70db003d63a976efc"],
    },
    citrea_devnet: {
      url: "https://rpc.devnet.citrea.xyz",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    avalanche_testnet: {
      url: "https://ava-testnet.public.blastapi.io/ext/bc/C/rpc",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.19",
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
