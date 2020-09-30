pragma solidity >=0.5.0 <=0.5.16;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/Math/SafeMath.sol";

import "./SimplePool.sol";

contract Geyser is Ownable {
	using SafeMath for uint256;

	event Staked(address indexed user, uint256 amount, uint256 total);
	event Unstaked(address indexed user, uint256 amount, uint256 total);
    event TokensClaimed(address indexed user, uint256 amount);
    event TokensLocked(uint256 amount, uint256 durationSec, uint256 total);
    event TokensUnlocked(uint256 amount, uint256 total);

	SimplePool private _stakedPool;
	SimplePool private _lockedPool;
    SimplePool private _unlockedPool;

	uint256 public constant BONUS_DECIMALS = 2;
    uint256 public startBonus = 0;
    uint256 public bonusPeriodSec = 0;

	uint256 public totalStakedShares = 0;
	uint256 public totalLockedShares = 0;
	uint256 private _totalStakingShareSeconds = 0;
	uint256 private _globalScheduledTimeStamp = now;

	struct Stakes {
		uint256 stakeShares;
		uint256 timeStamp;
	}

	struct TotalStakes {
		uint256 stakeShares;
	}

	mapping(address => TotalStakes) private _userTotalStakes;

    mapping(address => Stakes[]) private _userStakes;

    struct UnlockSchedule {
        uint256 initialLockedShares;
        uint256 unlockedShares;
        uint256 lastUnlockTimestampSec;
        uint256 endAtSec;
        uint256 durationSec;
    }

    UnlockSchedule[] public unlockSchedules;

	constructor(IERC20 stakeToken, IERC20 rewardToken, uint256 startBonus_, uint256 bonusPeriodSec_) public {
        // The start bonus must be some fraction of the max. (i.e. <= 100%)
        require(startBonus_ <= 10**BONUS_DECIMALS, 'TokenGeyser: start bonus too high');
        // If no period is desired, instead set startBonus = 100%
        // and bonusPeriod to a small value like 1sec.
        require(bonusPeriodSec_ != 0, 'TokenGeyser: bonus period is zero');
        // require(initialSharesPerToken > 0, 'TokenGeyser: initialSharesPerToken is zero');

        _stakedPool = new SimplePool(stakeToken);
        _lockedPool = new SimplePool(rewardToken);
        _unlockedPool = new SimplePool(rewardToken);

        startBonus = startBonus_;
        bonusPeriodSec = bonusPeriodSec_;

    }

    function stake(uint256 amount) external {
        require(amount > 0, 'Geyser: stake amount is zero');

        uint256 stakeShare = (totalStakedShares > 0)
            ? totalStakedShares.mul(amount).div(totalStaked())
            : amount;
        require(stakeShare > 0, 'TokenGeyser: Stake amount is too small');

        updateTotalStakedShareSeconds();

        TotalStakes storage totals = _userTotalStakes[msg.sender];
        totals.stakeShares = totals.stakeShares.add(stakeShare);

        Stakes memory newStake = Stakes(stakeShare, now);
        _userStakes[msg.sender].push(newStake);

        totalStakedShares = totalStakedShares.add(stakeShare);

        require(_stakedPool.token().transferFrom(msg.sender, address(_stakedPool), amount), 
        	'Geyser: transfer into staking pool failed');

        emit Staked(msg.sender, amount, totalStakedFor(msg.sender));
    }

    function unstake(uint256 amount) external {

    	updateTotalStakedShareSeconds();

        // checks
        require(amount > 0, 'Geyser: unstake amount is zero');
        require(totalStakedFor(msg.sender) >= amount,
            'Geyser: unstake amount is greater than total user stakes');
        uint256 stakingSharesToBurn = totalStakedShares.mul(amount).div(totalStaked());
        require(stakingSharesToBurn > 0, 'Geyser: Unable to unstake amount this small');

        TotalStakes storage totals = _userTotalStakes[msg.sender];
        Stakes[] storage accountStakes = _userStakes[msg.sender];

        uint256 stakingShareSecondsToBurn = 0;
        uint256 sharesLeftToBurn = stakingSharesToBurn;
        uint256 rewardAmount = 0;
        while (sharesLeftToBurn > 0) {
            Stakes storage lastStake = accountStakes[accountStakes.length - 1];
            uint256 stakeTimeSec = now.sub(lastStake.timeStamp);
            uint256 newStakingShareSecondsToBurn = 0;
            if (lastStake.stakeShares <= sharesLeftToBurn) {
                newStakingShareSecondsToBurn = lastStake.stakeShares.mul(stakeTimeSec);
                rewardAmount = computeRewardToken(rewardAmount, newStakingShareSecondsToBurn, stakeTimeSec);
                stakingShareSecondsToBurn = stakingShareSecondsToBurn.add(newStakingShareSecondsToBurn);
                sharesLeftToBurn = sharesLeftToBurn.sub(lastStake.stakeShares);
                accountStakes.length--;
            } else {
                newStakingShareSecondsToBurn = sharesLeftToBurn.mul(stakeTimeSec);
                rewardAmount = computeRewardToken(rewardAmount, newStakingShareSecondsToBurn, stakeTimeSec);
                stakingShareSecondsToBurn = stakingShareSecondsToBurn.add(newStakingShareSecondsToBurn);
                lastStake.stakeShares = lastStake.stakeShares.sub(sharesLeftToBurn);
                sharesLeftToBurn = 0;
            }
        }
        totals.stakeShares = totals.stakeShares.sub(stakingSharesToBurn);
        totalStakedShares = totalStakedShares.sub(stakingSharesToBurn);

        require(_stakedPool.transfer(msg.sender, amount),
            'Geyser: transfer out of staking pool failed');
        require(_unlockedPool.transfer(msg.sender, rewardAmount),
            'Geyser: transfer out of unlocked pool failed');

        emit Unstaked(msg.sender, amount, totalStakedFor(msg.sender));
        emit TokensClaimed(msg.sender, rewardAmount);

        require(totalStakedShares == 0 || totalStaked() > 0,
                "Geyser: Error unstaking. Staking shares exist, but no staking tokens do");
    }

    function computeRewardToken(uint256 currentRewardTokens, 
    	uint256 stakingShareSeconds, uint256 stakeTimeDurationSec) public view returns (uint256) {

    	require(totalUnlockedRewardPool() > 0, 'totalRewardPool is equal zero.');

    	require(stakingShareSeconds > 0, 'stakingShareSeconds is equal zero.');

    	require(totalUnlockedRewardPool().mul(stakingShareSeconds) > 0, 'totalRewardPool * stakingShareSeconds is equal to zero');

    	uint256 newRewardTokens =
            totalUnlockedRewardPool()
            .mul(stakingShareSeconds)
            .div(_totalStakingShareSeconds);

        if (stakeTimeDurationSec >= bonusPeriodSec) {
            return currentRewardTokens.add(newRewardTokens);
        }

        uint256 oneHundredPct = 10**BONUS_DECIMALS;
        require(oneHundredPct.sub(startBonus).mul(stakeTimeDurationSec) > 0, 'oneHundredPct.sub(startBonus).mul(stakeTimeDurationSec) is equal to zero');

        uint256 bonusedReward =
            startBonus
            .add(oneHundredPct.sub(startBonus).mul(stakeTimeDurationSec).div(bonusPeriodSec))
            .mul(newRewardTokens)
            .div(oneHundredPct);

        return currentRewardTokens.add(bonusedReward);
    }

    function totalStakedFor(address addr) public view returns (uint256) {
        return totalStakedShares > 0 ?
            totalStaked().mul(_userTotalStakes[addr].stakeShares).div(totalStakedShares) : 0;
    }

    function totalStaked() public view returns (uint256) {
        return _stakedPool.balance();
    }

    function token() external view returns (address) {
        return address(_unlockedPool.token());
    }

    function totalLockedRewardPool() public view returns (uint256) {
        return _lockedPool.balance();
    }

    function totalUnlockedRewardPool() public view returns (uint256) {
        return _unlockedPool.balance();
    }

    function lockRewardToken(uint256 amount, uint256 durationSec) external onlyOwner {
        updateTotalStakedShareSeconds();

        uint256 lockedTokens = totalLockedRewardPool();
        uint256 mintedLockedShares = (lockedTokens > 0)
            ? totalLockedShares.mul(amount).div(lockedTokens)
            : amount;

        UnlockSchedule memory schedule;
        schedule.initialLockedShares = mintedLockedShares;
        schedule.lastUnlockTimestampSec = now;
        schedule.endAtSec = now.add(durationSec);
        schedule.durationSec = durationSec;
        unlockSchedules.push(schedule);

        totalLockedShares = totalLockedShares.add(mintedLockedShares);

        require(_lockedPool.token().transferFrom(msg.sender, address(_lockedPool), amount),
            'Geyser: transfer into locked pool failed');
        emit TokensLocked(amount, durationSec, totalLockedRewardPool());
    }

    function unlockRewardToken() public returns (uint256) {
    	uint256 unlockedTokens = 0;
        uint256 lockedTokens = totalLockedRewardPool();

        if (totalLockedShares == 0) {
            unlockedTokens = lockedTokens;
        } else {
            uint256 unlockedShares = 0;
            for (uint256 s = 0; s < unlockSchedules.length; s++) {
                unlockedShares = unlockedShares.add(unlockScheduleShares(s));
            }
            unlockedTokens = unlockedShares.mul(lockedTokens).div(totalLockedShares);
            totalLockedShares = totalLockedShares.sub(unlockedShares);
        }

        if (unlockedTokens > 0) {
            require(_lockedPool.transfer(address(_unlockedPool), unlockedTokens),
                'TokenGeyser: transfer out of locked pool failed');
            emit TokensUnlocked(unlockedTokens, totalLockedRewardPool());
        }

        return unlockedTokens;
    }

    function unlockScheduleShares(uint256 s) private returns (uint256) {
        UnlockSchedule storage schedule = unlockSchedules[s];

        if(schedule.unlockedShares >= schedule.initialLockedShares) {
            return 0;
        }

        uint256 sharesToUnlock = 0;
        // Special case to handle any leftover dust from integer division
        if (now >= schedule.endAtSec) {
            sharesToUnlock = (schedule.initialLockedShares.sub(schedule.unlockedShares));
            schedule.lastUnlockTimestampSec = schedule.endAtSec;
        } else {
            sharesToUnlock = now.sub(schedule.lastUnlockTimestampSec)
                .mul(schedule.initialLockedShares)
                .div(schedule.durationSec);
            schedule.lastUnlockTimestampSec = now;
        }

        schedule.unlockedShares = schedule.unlockedShares.add(sharesToUnlock);
        return sharesToUnlock;
    }

    function updateTotalStakedShareSeconds() public {
    	unlockRewardToken();

        require( now >= _globalScheduledTimeStamp, 'now is not greater than _globalScheduledTimeStamp');

    	uint256 newStakingShareSeconds =
            now
            .sub(_globalScheduledTimeStamp)
            .mul(totalStakedShares);
        _totalStakingShareSeconds = _totalStakingShareSeconds.add(newStakingShareSeconds);
        _globalScheduledTimeStamp = now;
    }

}