var GeyserApp = artifacts.require("GeyserApp");
var SimpleToken = artifacts.require("SimpleToken");
var GeyserProxyFactory = artifacts.require("GeyserProxyFactory");

module.exports = function(deployer, networks, accounts) {
	const proxyAdmin = accounts[0];	
    deployer.deploy(GeyserApp).then(() => {
     	return deployer.deploy(GeyserProxyFactory, GeyserApp.address, proxyAdmin, '0x');
    })
};