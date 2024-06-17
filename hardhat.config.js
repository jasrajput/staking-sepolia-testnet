require("@nomicfoundation/hardhat-toolbox");
// require("@openzeppelin/hardhat-upgrades");
// require("@nomicfoundation/hardhat-verify");

// module.exports = {
//   solidity: "0.8.10",
//   networks: {
//     sepolia: {
//       url: `https://api.zan.top/node/v1/eth/sepolia/public`,
//       chainId: 11155111,
//       gas: "auto",
//       gasPrice: "auto",
//     },
//   },
// };


// module.exports = {
//   solidity: "0.8.24",
//   hardhat: {
//     forking: {
//       url: "https://mainnet.infura.io/v3/25901475a4d143d99f522385ae256dc4",
//     },
//     chainId: 1,
//     blockNumber: 19908621
//   }
// };


module.exports = {
  solidity: "0.8.24",
  networks: {
    sepolia: {
      url: vars.get("SEPOLIA_RPC_URL"),
      accounts: [vars.get('SEPOLIA_PRIVATE_KEY')],
    },
  },
  
  etherscan: {
    apiKey: vars.get('BSC_API_KEY'),
    customChains: [
      {
        network: "Sepolia",
        chainId: 11155111,
        urls: {
          apiURL: "https://sepolia.etherscan.io//api",
          browserURL: "https://sepolia.etherscan.io"
        }
      }
    ],
  }
};
