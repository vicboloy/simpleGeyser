var GeyserApp = artifacts.require("GeyserApp");
var SimpleToken = artifacts.require("SimpleToken");
var GeyserProxyFactory = artifacts.require("GeyserProxyFactory");

module.exports = function(deployer) {
  deployer.deploy(SimpleToken, "SimpleToken", "ST");
};
