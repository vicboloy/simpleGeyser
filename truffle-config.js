const path = require("path");

module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 7545,
      network_id: "5777"
    }
    // live: { ... }
  },
  compilers: {
    solc: {
      version: ">=0.5.0 <=0.6.2",
    },
  }
};
