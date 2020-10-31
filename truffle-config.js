const path = require("path");

module.exports = {

  plugins: ["solidity-coverage"],
  networks: {
    development: {
      host: "127.0.0.1", // ganache defaults
      port: 7545, // ganache defaults
      network_id: '*'
    },
    soliditycoverage: {
      port: 8545,
      host: "127.0.0.1",
      network_id: "*",
    }
  },
  compilers: {
    solc: {
      version: ">=0.6.0 <=0.6.2",
    }
  }
};
