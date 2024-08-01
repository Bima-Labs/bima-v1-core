import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import '@typechain/hardhat';
import '@nomicfoundation/hardhat-ethers';
import '@nomicfoundation/hardhat-chai-matchers';
import 'dotenv/config';

const config: HardhatUserConfig = {
  defaultNetwork: 'gate_testnet',

  etherscan: {
    apiKey: {
      // lorenzo_testnet: "abc",

      // gate_testnet:"9063a1a8a3ee226fa440779bc6f7015a",
      // bscTestnet:`CC7GINMBKSKVQZTXC9GD7M852K65CPEVRF`,
      polygon_amoy: `WIXGNHX39425CPDKS5TFBDJBKMGTDWR7QI,`,
    },
  },
  networks: {
    lorenzo_testnet: {
      url: 'https://rpc-testnet.lorenzo-protocol.xyz',
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    polygon_amoy: {
      url: 'https://rpc-amoy.polygon.technology',
      chainId: 80002,
      accounts: [
        'a0b8d309dd0afc95c94fc319f2de434f845a747d662c71ccbc08655c29299519',
      ],
      gasPrice: 25000000000, // 25 gwei in wei
    },
    gate_testnet: {
      url: 'https://meteora-evm.gatenode.cc',
      chainId: 85,
      accounts: [
        'ea5fbf909b888a1e810ef6ca42f06cb7eabc9a04095ec7e11fdeed7bb968ab07',
      ],
    },
    bsc_testnet: {
      url: 'https://data-seed-prebsc-2-s3.binance.org:8545/',
      chainId: 97,
      accounts: [
        'ea5fbf909b888a1e810ef6ca42f06cb7eabc9a04095ec7e11fdeed7bb968ab07',
      ],
    },
  },
  solidity: {
    compilers: [
      {
        version: '0.8.19',
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
