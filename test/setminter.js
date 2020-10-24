const { web3 } = require('@openzeppelin/test-environment');
const { expectRevert, expectEvent, BN, constants } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');
const ganache = require("ganache-core");
web3.setProvider(ganache.provider());

const Geyser = artifacts.require("GeyserApp");
const SimpleToken = artifacts.require("SimpleToken");

const AMPL_DECIMALS = 9;

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
		});
		it('should add minter role', async function () {
			const res = await dist.setMinter(user4);
			expectEvent(res, 'RoleGranted', {
		        account: user4,
		        sender: user1
		    });
		});	
		it('should add new minter and lock tokens', async function () {
			const res = await dist.setMinter(user4);
			const rewardSched = await dist.lockRewardToken($ST(100), ONE_YEAR, {from: user4});
			
		});	
	});

})