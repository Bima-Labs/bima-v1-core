import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@typechain/hardhat";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-chai-matchers";
import "dotenv/config";

require("@nomicfoundation/hardhat-foundry");

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
      fluent_testnet: "",
      filecoin_testnet: "",
      morph_testnet: "",
      bnb_testnet: "",
      godwoken_testnet: "",
      fantom_testnet: "",
      aurora_testnet: "",
      ethereum_sepolia_testnet: "",
      manta_pacific_sepolia_testnet:"",
      plume_devnet:"",
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
        network: "plume_devnet",
        chainId: 18230,

        urls: {
          browserURL: " https://devnet-explorer.plumenetwork.xyz/",
          apiURL: " https://devnet-explorer.plumenetwork.xyz/api",
        },
      },
      {
        network: "manta_pacific_sepolia_testnet",
        chainId: 3441006,

        urls: {
          browserURL: "https://manta-sepolia.explorer.caldera.xyz/",
          apiURL: "https://manta-sepolia.explorer.caldera.xyz/api",
        },
      },
      {
        network: "ethereum_sepolia_testnet",
        chainId: 11155111,

        urls: {
          browserURL: "https://sepolia.etherscan.io/",
          apiURL: "https://api-sepolia.etherscan.io/api",
        },
      },
      {
        network: "aurora_testnet",
        chainId: 1313161555,

        urls: {
          browserURL: "https://explorer.testnet.aurora.dev/",
          apiURL: "https://explorer.testnet.aurora.dev/api/",
        },
      },
      {
        network: "godwoken_testnet",
        chainId: 71401,

        urls: {
          browserURL: "https://v1.testnet.gwscan.com/",
          apiURL: "https://v1.testnet.gwscan.com/api",
        },
      },
      {
        network: "fantom_testnet",
        chainId: 4002,

        urls: {
          browserURL: "https://testnet.ftmscan.com/",
          apiURL: "https://testnet.ftmscan.com/api/",
        },
      },
      {
        network: "bnb_testnet",
        chainId: 97,

        urls: {
          browserURL: "https://testnet.bscscan.com/",
          apiURL: "https://api-testnet.bscscan.com/api",
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
        chainId: 808813,

        urls: {
          browserURL: "https://bob-sepolia.explorer.gobob.xyz/",
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
          browserURL: "https://sepolia.scrollscan.com/",
          apiURL: "https://sepolia.scrollscan.com/api",
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
          browserURL: "https://www.oklink.com/amoy",
          apiURL: "https://www.oklink.com/amoy/api",
        },
      },
      {
        network: "optimism_sepolia_testnet",
        chainId: 11155420,

        urls: {
          browserURL: "https://11155420.rpc.thirdweb.com/",
          apiURL: "https://11155420.rpc.thirdweb.com/api",
        },
      },
      {
        network: "x_layer_testnet",
        chainId: 195,
        urls: {
          browserURL: "https://endpoints.omniatech.io/v1/xlayer/testnet/public",
          apiURL: "https://endpoints.omniatech.io/v1/xlayer/testnet/public",
        },
      },
      {
        network: "moonbase_alpha_testnet",
        chainId: 10200,
        urls: {
          browserURL: "https://1287.rpc.thirdweb.com/${THIRDWEB_API_KEY}",
          apiURL: "https://1287.rpc.thirdweb.com/${THIRDWEB_API_KEY}",
        },
      },
      {
        network: "okx_testnet",
        chainId: 65,
        urls: {
          browserURL: "https://exchaintestrpc.okex.org",
          apiURL: "https://exchaintestrpc.okex.org",
        },
      },
      {
        network: "stratovm_testnet",
        chainId: 93747,
        urls: {
          browserURL: " https://explorer.stratovm.io",
          apiURL: "https://rpc.stratovm.io",
        },
      },
      {
        network: "morph_testnet",
        chainId: 2810,
        urls: {
          browserURL: "https://explorer-holesky.morphl2.io/",
          apiURL: "https://rpc-holesky.morphl2.io",
        },
      },
      {
        network: "minato_testnet",
        chainId: 1946,
        urls: {
          browserURL: "https://explorer-testnet.soneium.org/",
          apiURL: "https://rpc.minato.soneium.org/",
        },
      },
      {
        network: "polygon_zkevm_cardona",
        chainId: 2442,
        urls: {
          browserURL: "https://cardona-zkevm.polygonscan.com/",
          apiURL: "https://etherscan.cardona.zkevm-rpc.com/",
        },
      },
      {
        network: "rootstock_testnet",
        chainId: 31,
        urls: {
          browserURL: "https://explorer.testnet.rootstock.io/",
          apiURL: "https://rpc.testnet.rootstock.io/peahiFglhq1BRIz3Sz6ilSCrvTlsXP-T",
        },
      },
      {
        network: "merlin_testnet",
        chainId: 686868,
        urls: {
          browserURL: "https://testnet-explorer.merlinchain.io/",
          apiURL: "https://testnet-rpc.merlinchain.io/",
        },
      },
    ],
  },
  networks: {
    lorenzo_testnet: {
      url: "https://rpc-testnet.lorenzo-protocol.xyz",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    plume_devnet: {
      url: "https://devnet-rpc.plumenetwork.xyz",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    manta_pacific_sepolia_testnet: {
      url: "https://pacific-rpc.sepolia-testnet.manta.network/http",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    ethereum_sepolia_testnet: {
      url: `https://eth-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_SEPOLIA_TESTNET_KEY}`,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    aurora_testnet: {
      url: "https://testnet.aurora.dev",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    godwoken_testnet: {
      url: "https://v1.testnet.godwoken.io/rpc",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    fantom_testnet: {
      url: "https://rpc.testnet.fantom.network/",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    bnb_testnet: {
      url: "https://data-seed-prebsc-1-s1.bnbchain.org:8545",
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
      url: "https://bob-sepolia.rpc.gobob.xyz",
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
      url: "https://sepolia-rpc.scroll.io",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    optimism_sepolia_testnet: {
      url: "https://11155420.rpc.thirdweb.com/",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    x_layer_testnet: {
      url: "https://endpoints.omniatech.io/v1/xlayer/testnet/public",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },

    moonbase_alpha_testnet: {
      url: "https://1287.rpc.thirdweb.com",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },

    okx_testnet: {
      url: "https://exchaintestrpc.okex.org",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },

    morph_testnet: {
      url: "https://rpc-holesky.morphl2.io",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },

    stratovm_testnet: {
      url: "https://rpc.stratovm.io",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    minato_testnet: {
      url: "https://rpc.minato.soneium.org/",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    rootstock_testnet: {
      url: "https://rpc.testnet.rootstock.io/peahiFglhq1BRIz3Sz6ilSCrvTlsXP-T",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    merlin_testnet: {
      url: "https://testnet-rpc.merlinchain.io",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    polygon_zkevm_cardona: {
      url: "https://etherscan.cardona.zkevm-rpc.com/",
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
