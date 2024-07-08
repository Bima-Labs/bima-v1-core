import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@typechain/hardhat";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-chai-matchers";

const config: HardhatUserConfig = {
 // defaultNetwork: "polygon_amoy",



  etherscan: {
    apiKey: {
      lorenzo_testnet: 'abc'
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
    ],
  },
  networks: {
    lorenzo_testnet: {
      url: "https://rpc-testnet.lorenzo-protocol.xyz",
      accounts: [
        "b5b0471933a4f28530ea6347b5219e1379899c476494323c446690c7ae913248",
        "d33a05f394a86fe0675730dad2f076eec5e6be5301b6af8efbf1b898b891d913",
        "6939d87023d9bb163492532b7fcbae6a575b7516cd824519327db7c44f089d44",
      ],
    },
    polygon_amoy: {
      url: "https://rpc-amoy.polygon.technology",
      accounts: [
        "7c5b27c4f043051e405d03469e3f9dfe5b65df74376dcaf70db003d63a976efc",
      ],
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
