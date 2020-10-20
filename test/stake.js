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

let simpleToken, dist, contractOwner, user1, user2, user3;

contract('Geyser', (accounts) => {
	describe('staking', function () {
		beforeEach('setup contracts', async function () {

			user1 = accounts[0];
			user2 = accounts[1];
			user3 = accounts[2];

			simpleToken = await SimpleToken.new("Simple Token", "ST");

			const startBonus = 50;
	    	const bonusPeriod = 86400;
			dist = await Geyser.new();
			dist.initialize(simpleToken.address, simpleToken.address, user1);
			// contractOwner = await dist.owner();
		});

		describe('stake', function () {
			describe('when the amount is 0', function () {
				it('should fail', async function () {
					await simpleToken.approve(dist.address, $ST(1000))
					await expectRevert.unspecified(dist.stake($ST(0)));
				});
			});
		});

		describe('when totalStaked is equal 0', function () {
			beforeEach(async function () {
				expect(await dist.totalStaked.call()).to.be.bignumber.equal($ST(0));
				await simpleToken.approve(dist.address, $ST(100));
			});
			it('should update the total staked', async function () {
				await dist.stake($ST(100));
				expect(await dist.totalStaked.call()).to.be.bignumber.equal($ST(100));
				expect(await dist.totalStakedFor.call(user1)).to.be.bignumber.equal($ST(100));
			});
			it('should log Staked', async function () {
	        const r = await dist.stake($ST(100));
	        expectEvent(r, 'Staked', {
	          user: user1,
	          amount: $ST(100),
	          total: $ST(100)
	        });
	      });
		});

		describe('when totalStaked greater than 0', function (){
			beforeEach(async function () {
				expect(await dist.totalStaked.call()).to.be.bignumber.equal($ST(0));
				await simpleToken.transfer(user2, $ST(50));
				expect(await simpleToken.balanceOf(user2)).to.be.bignumber.equal($ST(50));
				await simpleToken.approve(dist.address, $ST(50), { from: user2 });
	        	await dist.stake($ST(50), { from: user2 });
	        	await simpleToken.approve(dist.address, $ST(150));
	        	await dist.stake($ST(150));
			});
			it('should update the total staked to 200', async function () {
				expect(await dist.totalStaked.call()).to.be.bignumber.equal($ST(200));
	        	expect(await dist.totalStakedFor.call(user2)).to.be.bignumber.equal($ST(50));
	        	expect(await dist.totalStakedFor.call(user1)).to.be.bignumber.equal($ST(150));
			});
		});

		describe('when user3 stake multiple times, token balance decrease and totalStakedFor increases', function () {
			beforeEach(async function () {
				expect(await dist.totalStaked.call()).to.be.bignumber.equal($ST(0));
				await simpleToken.transfer(user3, $ST(100));
				expect(await simpleToken.balanceOf(user3)).to.be.bignumber.equal($ST(100));
				await simpleToken.approve(dist.address, $ST(100), { from: user3 });
				await dist.stake($ST(50), { from: user3 });
			});
			it('balance is equal to 0 and totalStakedFor = 100', async function() {
				expect(await simpleToken.balanceOf.call(user3)).to.be.bignumber.equal($ST(50));
				expect(await dist.totalStakedFor.call(user3)).to.be.bignumber.equal($ST(50));
				await dist.stake($ST(50), { from: user3 });
				expect(await simpleToken.balanceOf.call(user3)).to.be.bignumber.equal($ST(0));
				expect(await dist.totalStakedFor.call(user3)).to.be.bignumber.equal($ST(100));
			});
		});

		describe('when multiple users stakes', function () {
			beforeEach(async function () {
				expect(await dist.totalStaked.call()).to.be.bignumber.equal($ST(0));
				await simpleToken.transfer(user2, $ST(100));
				await simpleToken.transfer(user3, $ST(100));
				expect(await simpleToken.balanceOf(user2)).to.be.bignumber.equal($ST(100));
				expect(await simpleToken.balanceOf(user3)).to.be.bignumber.equal($ST(100));
				await simpleToken.approve(dist.address, $ST(100), { from: user2 });
				await dist.stake($ST(50), { from: user2 });
				await simpleToken.approve(dist.address, $ST(100), { from: user3 });
				await dist.stake($ST(100), { from: user3 });
			});
			it('should update totalStaked to 100', async function () {
				expect(await simpleToken.balanceOf.call(user2)).to.be.bignumber.equal($ST(50));
				expect(await dist.totalStakedFor.call(user2)).to.be.bignumber.equal($ST(50));
				expect(await simpleToken.balanceOf.call(user3)).to.be.bignumber.equal($ST(0));
				expect(await dist.totalStakedFor.call(user3)).to.be.bignumber.equal($ST(100));
				expect(await dist.totalStaked.call()).to.be.bignumber.equal($ST(150));
			});
		});
	});
});