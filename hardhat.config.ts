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
      zeta_testnet: "",
      arbitrum_testnet: "",
      movement_testnet: "",
      berachain_testnet: "",
      scroll_testnet: "",
      blast_testnet: "",
      polygon_testnet: "",
      fluent_testnet:"",
      filecoin_testnet:"",
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
        network: "filecoin_testnet",
        chainId: 314159,

        urls: {
          browserURL: "https://calibration.filscan.io/en/",
          apiURL: "https://calibration.filscan.io/en/api",
        },
      },
      {
        network: "fluent_testnet",
        chainId: 20993,

        urls: {
          browserURL: "https://blockscout.dev.thefluent.xyz/",
          apiURL: "https://blockscout.dev.thefluent.xyz/api",
        },
      },
      {
        network: "blast_testnet",
        chainId: 168587773,

        urls: {
          browserURL: "https://testnet.blastscan.io/",
          apiURL: "https://api-sepolia.blastscan.io/api",
        },
      },
      {
        network: "movement_testnet",
        chainId: 30732,

        urls: {
          browserURL: "https://testnet.movementlabs.xyz/",
          apiURL: "https://testnet.movementlabs.xyz/api",
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
        network: "arbitrum_testnet",
        chainId: 421614,

        urls: {
          browserURL: "https://sepolia.arbiscan.io/",
          apiURL: "https://api-sepolia.arbiscan.io/api",
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
      {
        network: "zeta_testnet",
        chainId: 7001,

        urls: {
          browserURL: "https://athens.explorer.zetachain.com/",
          apiURL: "https://athens.explorer.zetachain.com/",
        },
      },
      {
        network: "bob_testnet",
        chainId: 111,

        urls: {
          browserURL: "https://testnet.rpc.gobob.xyz/",
          apiURL: "https://testnet.rpc.gobob.xyz/",
        },
      },
      {
        network: "core_testnet",
        chainId: 1115,

        urls: {
          browserURL: "https://rpc.test.btcs.network",
          apiURL: "https://rpc.test.btcs.network",
        },
      },
      {
        network: "holesky_testnet",
        chainId: 17000,

        urls: {
          browserURL:
            "https://holesky-eth.w3node.com/f1ef94bb8175b1a8f2357a29663a3b8a5b43906d28879e114b8c225a47811c14/api",
          apiURL: "https://holesky-eth.w3node.com/f1ef94bb8175b1a8f2357a29663a3b8a5b43906d28879e114b8c225a47811c14/api",
        },
      },
      {
        network: "bitlayer_testnet",
        chainId: 200810,

        urls: {
          browserURL: "https://testnet-rpc.bitlayer.org",
          apiURL: "https://testnet-rpc.bitlayer.org",
        },
      },
      {
        network: "scroll_testnet",
        chainId: 534351,

        urls: {
          browserURL: "https://scroll-sepolia.drpc.org",
          apiURL: "https://scroll-sepolia.drpc.org",
        },
      },
      {
        network: "berachain_testnet",
        chainId: 80084,

        urls: {
          browserURL: "https://bartio.rpc.berachain.com",
          apiURL: "https://bartio.rpc.berachain.com",
        },
      },
      {
        network: "polygon_testnet",
        chainId: 80002,

        urls: {
          browserURL: "https://rpc-amoy.polygon.technology",
          apiURL: "https://rpc-amoy.polygon.technology",
        },
      },
    ],
  },
  networks: {
    lorenzo_testnet: {
      url: "https://rpc-testnet.lorenzo-protocol.xyz",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    filecoin_testnet: {
      url: "https://filecoin-calibration.chainup.net/rpc/v1",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    fluent_testnet: {
      url: "https://rpc.dev.thefluent.xyz/",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    movement_testnet: {
      url: "https://mevm.devnet.imola.movementlabs.xyz/",
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
    polygon_testnet: {
      url: "https://rpc-amoy.polygon.technology",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    citrea_devnet: {
      url: "https://rpc.devnet.citrea.xyz",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    arbitrum_testnet: {
      url: "https://arbitrum-sepolia.blockpi.network/v1/rpc/public",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    avalanche_testnet: {
      url: "https://ava-testnet.public.blastapi.io/ext/bc/C/rpc",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    zeta_testnet: {
      url: "https://zeta-chain-testnet.drpc.org",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    bob_testnet: {
      url: "https://testnet.rpc.gobob.xyz",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    holesky_testnet: {
      url: "https://holesky-eth.w3node.com/f1ef94bb8175b1a8f2357a29663a3b8a5b43906d28879e114b8c225a47811c14/api",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    bitlayer_testnet: {
      url: "https://testnet-rpc.bitlayer.org",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    core_testnet: {
      url: "https://rpc.test.btcs.network",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    berachain_testnet: {
      url: "https://bartio.rpc.berachain.com",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    blast_testnet: {
      url: "https://sepolia.blast.io",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    scroll_testnet: {
      url: "https://scroll-sepolia.drpc.org",
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
