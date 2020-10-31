const { web3 } = require('@openzeppelin/test-environment');
const { expectRevert, expectEvent, BN, constants } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');
const ganache = require("ganache-core");
web3.setProvider(ganache.provider());

const Geyser = artifacts.require("GeyserApp");
const SimpleToken = artifacts.require("SimpleToken");

const AMPL_DECIMALS = 9;

const ONE_YEAR = 1 * 365 * 24 * 3600;
function $ST (x) {
  return new BN(x * (10 ** AMPL_DECIMALS));
}

let simpleToken, dist, contractOwner, user1, user2, user3, user4;

contract('Geyser', (accounts) => {
	describe('Add minter role', function () {
		beforeEach('setup contracts', async function () {
			user1 = accounts[0];
			user2 = accounts[1];
			user3 = accounts[2];
			user4 = accounts[3];



			simpleToken = await SimpleToken.new("SimpleToken", "ST");

			dist = await Geyser.new();
			dist.initialize(simpleToken.address, simpleToken.address, user1);

			await simpleToken.approve(dist.address, $ST(10000), { from: user1 });
		    await simpleToken.approve(dist.address, $ST(10000), { from: user2 });
		    await simpleToken.approve(dist.address, $ST(10000), { from: user4 });
		    await simpleToken.transfer(user1, $ST(10000));
		    await simpleToken.transfer(user2, $ST(10000));
		    await simpleToken.transfer(user4, $ST(10000));
		});
		it('should add minter role', async function () {
			const res = await dist.setAdmin(user2);
			expectEvent(res, 'RoleGranted', {
		        account: user2,
		        sender: user1
		    });
		});	
		it('should add new admin and lock tokens', async function () {
			const res = await dist.setAdmin(user3);
			expect(await dist.hasAdminRole(user3)).to.equal(true);
		});	
		it('should renounce added admin', async function () {
			const res = await dist.setAdmin(user3);
			expect(await dist.hasAdminRole(user3)).to.equal(true);
			await dist.renounceAdmin({from:user3});
			expect(await dist.hasAdminRole(user3)).to.equal(false);
		});	
	});

})