import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import '@typechain/hardhat';
import '@nomicfoundation/hardhat-ethers';
import '@nomicfoundation/hardhat-chai-matchers';
import 'dotenv/config';

const config: HardhatUserConfig = {
  // defaultNetwork: 'berachain_testnet',

  etherscan: {
    apiKey: {
      // lorenzo_testnet: "abc",
      berachain_testnet:"abc"

    },
  },
  networks: {
    lorenzo_testnet: {
      url: 'https://rpc-testnet.lorenzo-protocol.xyz',
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    berachain_testnet: {
      url:'https://bartio.rpc.berachain.com',
      chainId:80084,
      accounts: [
        'a0b8d309dd0afc95c94fc319f2de434f845a747d662c71ccbc08655c29299519',
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
