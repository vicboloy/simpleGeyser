const { web3 } = require('@openzeppelin/test-environment');
const { expectRevert, expectEvent, BN, constants } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const ganache = require("ganache-core");
web3.setProvider(ganache.provider());
const timehelper = require('ganache-time-traveler');

const _require = require('app-root-path').require;
// const BlockchainCaller = _require('/util/blockchain_caller');
// const chain = new BlockchainCaller(web3);
const { TimeController } = _require('/test/timehelper');

const Geyser = artifacts.require("GeyserApp");
const SimpleToken = artifacts.require("SimpleToken");

const ONE_YEAR = 1 * 365 * 24 * 3600;
let simpleToken, dist, contractOwner, user1, user2, user3, snapshotId;

const ST_DECIMALS = 9;
function $ST (x) {
  return new BN(x * (10 ** ST_DECIMALS));
}

async function totalRedeemableRewards (account) {
  return (await dist.updateAccounting.call({ from: account }))[4];
}

contract('Geyser', (accounts) => {
	
	async function setupContractAndAccounts () {
	  // const accounts = await chain.getUserAccounts();
	  // owner = web3.utils.toChecksumAddress(accounts[0]);
	  // user1 = web3.utils.toChecksumAddress(accounts[1]);
	  // user2 = web3.utils.toChecksumAddress(accounts[2]);
	  // user3 = web3.utils.toChecksumAddress(accounts[3]);
	  owner = accounts[0];
	  user1 = accounts[1];
	  user2 = accounts[2];
	  user3 = accounts[3];


	  st = await SimpleToken.new("SimpleToken", "ST");

	  const startBonus = 50; // 50%
	  const bonusPeriod = 86400; // 1 Day
	  dist = await Geyser.new();
	  await dist.initialize(st.address, st.address, owner);

	  await dist.setMinter(user1, { from: owner });

	  // await st.approve(dist.address, $ST(1000), { from: user1 });
	  
	  await st.approve(dist.address, $ST(10000), { from: user1 });
	  await st.approve(dist.address, $ST(10000), { from: user2 });
	  await st.approve(dist.address, $ST(10000), { from: user3 });
	  await st.transfer(user1, $ST(10000));
	  await st.transfer(user2, $ST(10000));
	  await st.transfer(user3, $ST(10000));
	  // await st.approve(dist.address, $ST(1000), { from: user2 });
	  await st.approve(dist.address, $ST(10000), { from: owner });
	}

	describe('unstaking', function (){
		beforeEach('initialize contracts', async function (){
			await setupContractAndAccounts();
		});

		describe('unstake', function (){
			describe('when amount is 0', function () {
				it('should fail', async function () {
					await dist.stake(50, { from: user1 });
					await expectRevert(
			          dist.unstake(0, { from: user1 }),
			          'GeyserApp: unstake amount is zero'
			        );
				});
			});
		});

		describe('when single user fully unstake staked tokens', function () {
			beforeEach(async function () {
		        const rewardSched = await dist.lockRewardToken($ST(100), ONE_YEAR, {from: user1});
		        expect(await dist.totalLocked.call()).to.be.bignumber.equal($ST(100));
		        let snapshot = await timehelper.takeSnapshot();
				snapshotId = snapshot['result'];
		        const stake = await dist.stake($ST(50), { from: user2 });
		        await timehelper.advanceTimeAndBlock(ONE_YEAR + 60);
		        await dist.updateTotals.call();
		    });
		    afterEach(async() => {
       			await timehelper.revertToSnapshot(snapshotId);
   			});
		    it('should update the total staked and rewards', async function () {
		        await dist.unstake($ST(50), { from: user2 });
		        expect(await dist.totalStaked.call()).to.be.bignumber.equal($ST(0));
				expect(await dist.totalStakedFor.call(user2)).to.be.bignumber.equal($ST(0));
				expect(await dist.totalUnlocked.call()).to.be.bignumber.equal($ST(0));
      		});
      		it('should transfer back staked tokens + reward tokens', async function () {
      			const _b = await st.balanceOf.call(user2);
		        await dist.unstake($ST(30), { from: user2 });
		        const b = await st.balanceOf.call(user2);
		        expect(b).to.be.bignumber.equal(_b.add($ST(30).add($ST(60))));
      		});
      		it('should log Unstaked', async function () {
      			const r = await dist.unstake($ST(50), { from: user2 });
		        expectEvent(r, 'Unstaked', {
		          user: user2,
		          amount: $ST(50),
		          total: $ST(0)
		        });
      		});
      		it('should log RewardToken', async function () {
      			const r = await dist.unstake($ST(30), { from: user2 });
		        expectEvent(r, 'TokensClaimed', {
		          user: user2,
		          amount: $ST(60)
		        });
      		});
		});
		describe('when single user unstake with early bonus', async function () {
			const timeController = new TimeController();
			const ONE_HOUR = 3600;
		    beforeEach(async function () {
		        await dist.lockRewardToken($ST(1000), ONE_HOUR, { from : user1 });
		        let snapshot = await timehelper.takeSnapshot();
				snapshotId = snapshot['result'];
		        await dist.stake($ST(500), { from: user2 });
		        await timehelper.advanceTimeAndBlock(12 * ONE_HOUR);
		        await dist.updateTotals.call();
		    });
		    afterEach(async() => {
       			await timehelper.revertToSnapshot(snapshotId);
   			});
		    it('should update total stake and rewards', async function () {
		    	expect(await dist.totalStaked.call()).to.be.bignumber.equal($ST(500));
		    	await dist.unstake($ST(250), { from: user2 });
		    	expect(await dist.totalStaked.call()).to.be.bignumber.equal($ST(250));
       			expect(await dist.totalStakedFor.call(user2)).to.be.bignumber.equal($ST(250));
       			expect(await dist.totalUnlocked.call()).to.be.bignumber.equal($ST(500));
		    });
		    it('should log Unstaked', async function () {
      			const r = await dist.unstake($ST(250), { from: user2 });
		        expectEvent(r, 'Unstaked', {
		          user: user2,
		          amount: $ST(250),
		          total: $ST(250)
		        });
      		});
      		it('should log RewardToken', async function () {
      			const r = await dist.unstake($ST(250), { from: user2 });
		        expectEvent(r, 'TokensClaimed', {
		          user: user2,
		          amount: $ST(500)
		        });
      		});
		});
		describe('when single user stakes multiple times', async function () {
			const timeController = new TimeController();
			const ONE_HOUR = 3600;
		    beforeEach(async function () {
		        await dist.lockRewardToken($ST(1000), ONE_HOUR, { from : user1 });
		        let snapshot = await timehelper.takeSnapshot();
				snapshotId = snapshot['result'];
		        await dist.stake($ST(500), { from: user3 });
		        await timehelper.advanceTimeAndBlock(12 * ONE_HOUR);
		        await dist.updateTotals.call();
		    });
		    afterEach(async() => {
	       		await timehelper.revertToSnapshot(snapshotId);
	   		});
	   		it('should update total staked + rewards', async function () {
	   			
	   		});
		});
	});
	
});