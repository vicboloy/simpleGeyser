const { web3 } = require('@openzeppelin/test-environment');
const { expectRevert, expectEvent, BN, constants } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');
const ganache = require("ganache-core");
web3.setProvider(ganache.provider());

const Geyser = artifacts.require("GeyserApp");
const GeyserV1 = artifacts.require("GeyserAppV1");
const GeyserProxyFactory = artifacts.require("GeyserProxyFactory");
const SimpleToken = artifacts.require("SimpleToken");

const AMPL_DECIMALS = 9;

function $ST (x) {
  return new BN(x * (10 ** AMPL_DECIMALS));
}

let token, geyserContract, geyserProxy, proxy, proxyAdmin, geyserAdmin, user1, user2, user3;

contract('GeyserProxyFactory', (accounts) => {

	describe('Geyser Proxy', function () {
		beforeEach('setup contracts', async function () {
			proxyAdmin = accounts[0];
			geyserAdmin = accounts[1];
			user1 = accounts[2];
			user2 = accounts[3];
			user3 = accounts[4];

			token = await SimpleToken.new("Simple Token", "ST");
			geyserContract = await Geyser.new();
		});
		describe('When proxy factory initialized', function () {
			beforeEach('initialize geyser proxy', async function (){
				proxy = await GeyserProxyFactory.new(geyserContract.address, proxyAdmin, '0x');
			});
			it('should initialize admin and implementation', async function () {
				const owner = await proxy.owner.call();
				const impl = await proxy.impl.call();
				expect(owner).to.equal(proxyAdmin);
				expect(impl).to.equal(geyserContract.address)
				expect(await proxy.implementation.call({from:proxyAdmin})).to.equal(geyserContract.address);
				expect(await proxy.admin.call({from:proxyAdmin})).to.equal(proxyAdmin);
			});
			it('should change admin', async function () {
				const newAdmin = accounts[5];
				const rst = await proxy.changeAdmin(newAdmin, {from:proxyAdmin});
		        expectEvent(rst, 'AdminChanged', {
		          previousAdmin: proxyAdmin,
		          newAdmin: newAdmin
		        });
				expect(await proxy.admin.call({from:newAdmin})).to.equal(newAdmin);
			});
		});
		describe('When proxy initialize', function () {
			beforeEach('initialize geyser proxy', async function (){
				proxy = await GeyserProxyFactory.new(geyserContract.address, proxyAdmin, '0x');
				geyserProxy = await Geyser.at(proxy.address);
				await geyserProxy.initialize(token.address, token.address, geyserAdmin, { from: geyserAdmin });
			});
			it('should initialize geyser', async function (){
				expect(await geyserProxy.token({from:geyserAdmin})).to.equal(token.address);
				expect(await geyserProxy.getStakingToken({from:geyserAdmin})).to.equal(token.address);
				expect(await geyserProxy.totalStaked({from:geyserAdmin})).to.be.bignumber.equal($ST(0));
				expect(await geyserProxy.totalLocked({from:geyserAdmin})).to.be.bignumber.equal($ST(0));
				expect(await geyserProxy.totalUnlocked({from:geyserAdmin})).to.be.bignumber.equal($ST(0));
			});
		});
		describe('When upgrade implementation', function () {
			beforeEach('upgrade implementation', async function (){
				proxy = await GeyserProxyFactory.new(geyserContract.address, proxyAdmin, '0x');
				geyserProxy = await Geyser.at(proxy.address);
				await geyserProxy.initialize(token.address, token.address, geyserAdmin, { from: geyserAdmin });
				this.geyserV1 = await GeyserV1.new();
				await proxy.upgradeTo(this.geyserV1.address, {from:proxyAdmin});
				geyserProxy = await GeyserV1.at(proxy.address);
			});
			it('should update to new implementation', async function (){
				expect(await proxy.implementation.call({from:proxyAdmin})).to.equal(this.geyserV1.address);
			});
			it('should update state of new implementation with old implementation', async function (){
				expect(await geyserProxy.token({from:geyserAdmin})).to.equal(token.address);
				expect(await geyserProxy.getStakingToken({from:geyserAdmin})).to.equal(token.address);
				expect(await geyserProxy.totalStaked({from:geyserAdmin})).to.be.bignumber.equal($ST(0));
				expect(await geyserProxy.totalLocked({from:geyserAdmin})).to.be.bignumber.equal($ST(0));
				expect(await geyserProxy.totalUnlocked({from:geyserAdmin})).to.be.bignumber.equal($ST(0));
			});
			it('should have upgraded version of geyser', async function (){
				await geyserProxy.setVersion("Verrsion 1", {from:geyserAdmin});
				expect(await geyserProxy.getVersion({from: geyserAdmin}));
			});
		});
	});
});