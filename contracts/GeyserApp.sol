pragma solidity >=0.5.0 <=0.6.2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "./SimplePool.sol";
import "./AccessRule.sol";

contract GeyserApp is AccessRule, Pausable {
	using SafeMath for uint256;

	event Staked(address indexed user, uint256 amount, uint256 total);
	event Unstaked(address indexed user, uint256 amount, uint256 total);
    event TokensClaimed(address indexed user, uint256 amount);
    event TokensLocked(uint256 amount, uint256 durationSec, uint256 total);
    event TokensUnlocked(uint256 amount, uint256 total);

    SimplePool private stakedPool;
	SimplePool private lockedPool;
    SimplePool private unlockedPool;

    uint256 private globalTotalStakedDuration;
    uint256 private globalLastStakedTimeStamp;

    struct UserStakes {
    	uint256 staked;
    	uint256 timeStamp;
    }

    struct TotalUserStakes {
    	uint256 totalStaked;
    	uint256 firstStakedTimestamp;
    }

    mapping(address => TotalUserStakes) private totalUserStakes;

    mapping(address => UserStakes[]) private userStakes;

    struct RewardSchedule {
        uint256 initialLockedToken;
        uint256 unlockedToken;
        uint256 lastUnlockTimestamp;
        uint256 endTimestamp;
        uint256 duration;
    }

    RewardSchedule[] public rewardSchedule;

    /**
     *	@param _stakeToken The token users deposit as stake.
     *	@param _rewardToken The token users receives as reward as they unstake.
    **/
    function initialize(IERC20 _stakeToken, IERC20 _rewardToken, address _rootAdmin) public initializer {
        AccessRule.initialize(_rootAdmin);
    	globalTotalStakedDuration = 0;
    	globalLastStakedTimeStamp = now;
        stakedPool = new SimplePool();
        stakedPool.initialize(_stakeToken, address(this));
        lockedPool = new SimplePool();
        lockedPool.initialize(_rewardToken, address(this));
        unlockedPool = new SimplePool();
        unlockedPool.initialize(_rewardToken, address(this));
    }

    /**
     * @return The token users deposit as stake.
     */
    function getStakingToken() public view returns (IERC20) {
        return stakedPool.token();
    }

    /**
     *	@dev Transfers amount of token to be deposit by the user.
     *	@param _amount Number of deposit tokens to be stake by the user.
    **/
    function stake(uint256 _amount) external whenNotPaused {
        require(_amount > 0, 'Geyser: stake _amount is zero');

        updateTotals();

        TotalUserStakes storage totals = totalUserStakes[_msgSender()];
        if(totals.totalStaked == 0 ) {
        	totals.firstStakedTimestamp = now;	
        }
        totals.totalStaked = totals.totalStaked.add(_amount);
        

        UserStakes memory newStake = UserStakes(_amount, now);
        userStakes[_msgSender()].push(newStake);

        // totalStaked = totalStaked.add(_amount);

        require(stakedPool.token().transferFrom(_msgSender(), address(stakedPool), _amount), 
        	'Geyser: transfer into staking pool failed');

        emit Staked(_msgSender(), _amount, totalStakedFor(_msgSender()));
    }

    /** @dev Unstakes a certain amount of previously deposited tokens by the user. The user also receives
     *	their eligible amount of reward tokens.
     *	@param _amount - Number of deposit tokens to unstake / withdraw.
    **/
    function unstake(uint256 _amount) external whenNotPaused {
    	updateTotals();

    	require(_amount > 0, 'GeyserApp: unstake amount is zero');

    	TotalUserStakes storage totals = totalUserStakes[_msgSender()];
        UserStakes[] storage stakes = userStakes[_msgSender()];

        uint256 stakesToBurn = _amount;
        uint256 rewardAmount = 0;
        uint256 totalStakedDurationToBurn = 0;
        uint256 stakesCount = stakes.length;
        while (stakesToBurn > 0) {
        	UserStakes storage lastStake = stakes[stakesCount - 1];
        	uint256 stakeDuration = now.sub(lastStake.timeStamp);
        	uint256 stakeDurationToBurn = 0;
        	if(lastStake.staked <= stakesToBurn) {
        		stakeDurationToBurn = lastStake.staked.mul(stakeDuration);
        		rewardAmount = computeNewReward(rewardAmount, stakeDurationToBurn);
        		totalStakedDurationToBurn = totalStakedDurationToBurn.add(stakeDurationToBurn);
        		stakesToBurn = stakesToBurn.sub(lastStake.staked);
        		stakesCount--;
        	} else {
        		stakeDurationToBurn = stakesToBurn.mul(stakeDuration);
        		rewardAmount = computeNewReward(rewardAmount, stakeDurationToBurn);
        		totalStakedDurationToBurn = totalStakedDurationToBurn.add(stakeDurationToBurn);
        		lastStake.staked = lastStake.staked.sub(stakesToBurn);
        		stakesToBurn = 0;
        	}
        }

        totals.totalStaked = totals.totalStaked.sub(_amount);

        globalTotalStakedDuration = globalTotalStakedDuration.sub(totalStakedDurationToBurn);

        // interactions
        require(stakedPool.transfer(_msgSender(), _amount),
            'GeyserApp: transfer out of staking pool failed');
        require(unlockedPool.transfer(_msgSender(), rewardAmount),
            'GeyserApp: transfer out of unlocked pool failed');

        emit Unstaked(_msgSender(), _amount, totalStakedFor(_msgSender()));
        emit TokensClaimed(_msgSender(), rewardAmount);

    }

    /**
     * @dev Compute the current reward token based on the stake duration multiply by the total rewards
     *		and divided  by the global staked durationSecn.
     * @param _currentRewardTokens The current number of distribution tokens already alotted for this
     *                            unstake op. Any bonuses are already applied.
     * @param _stakingShareSeconds The stakingShare-seconds that are being burned for new
     *                            distribution tokens.
     * @return Updated amount of distribution tokens to award.
     */
    function computeNewReward(uint256 _currentRewardTokens,
                                uint256 _stakingShareSeconds) private view returns (uint256) {

        uint256 newRewardTokens =
            totalUnlocked()
            .mul(_stakingShareSeconds)
            .div(globalTotalStakedDuration);


        return _currentRewardTokens.add(newRewardTokens);
    }

    /**
     *	@dev A function that is called globally to update the total and global timestamp as state of the system
     *		 and current total rewards of the user.
    **/
    function updateTotals() public returns (uint256) {
    	unlockRewardToken();

    	uint256 currentStakeDuration = 
    		now
    		.sub(globalLastStakedTimeStamp)
    		.mul(totalStaked());

    	globalTotalStakedDuration = globalTotalStakedDuration.add(currentStakeDuration);
    	globalLastStakedTimeStamp = now;

    	// TotalUserStakes storage totals = totalUserStakes[_msgSender()];
    	// uint256 totalUserStakedDuration = 
    	// 	now
    	// 	.sub(totals.firstStakedTimestamp)
    	// 	.mul(totals.totalStaked);

    	// uint256 totalUserRewards = (globalTotalStakedDuration > 0)
    	// 	? totalUnlocked().mul(totalUserStakedDuration).div(globalTotalStakedDuration)
    	// 	: 0;

    	return totalUnlocked();


    }

    /**
     * @param _addr The user to look up staking information for.
     * @return The number of staking tokens deposited for addr.
     */
    function totalStakedFor(address _addr) public view returns (uint256) {
        return totalStaked() > 0 ?
           totalUserStakes[_addr].totalStaked : 0;
    }

    /**
     * @return The total number of deposit tokens staked globally, by all users.
     */
    function totalStaked() public view returns (uint256) {
        return stakedPool.balance();
    }

    /**
     * @dev Note that this application has a staking token as well as a distribution token, which
     * may be different. This function is required by EIP-900.
     * @return The deposit token used for staking.
     */
    function token() external view returns (address) {
        return address(getStakingToken());
    }

    /**
     * @return Total number of locked distribution tokens.
     */
    function totalLocked() public view returns (uint256) {
        return lockedPool.balance();
    }

    /**
     * @return Total number of unlocked distribution tokens.
     */
    function totalUnlocked() public view returns (uint256) {
        return unlockedPool.balance();
    }

    /**
     * @return Number of unlock schedules.
     */
    function unlockScheduleCount() public view returns (uint256) {
        return rewardSchedule.length;
    }

    /**
     *	@dev This function allows the user that has admin role to add more locked tokens
     * 		 and duration that will begin unlocking until the duration.
     *	@param _amount Number of reward token that is in the lock state and to be transfered from the caller
     *	@param _duration Length of time to linear unlock the tokens.
    **/
    function lockRewardToken(uint256 _amount, uint256 _duration) external onlyMinter whenNotPaused {
    	updateTotals();
    	
    	RewardSchedule memory schedule;
    	schedule.initialLockedToken = _amount;
    	schedule.lastUnlockTimestamp = now;
    	schedule.endTimestamp = now.add(_duration);
    	schedule.duration = _duration;
    	rewardSchedule.push(schedule);

    	require(lockedPool.token().transferFrom(_msgSender(), address(lockedPool), _amount),
            'GeyserApp: transfer into locked pool failed');
        emit TokensLocked(_amount, _duration, totalLocked());

    }

    /**
     *	@dev Moves the tokens that is locked to unlocked pool according to the defined unlock duration.
     *	@return Number of newly unlock reward tokens.
    **/
    function unlockRewardToken() public whenNotPaused returns (uint256) {
    	uint256 unlockedRewardTokens = 0;
    	uint256 lockRewardTokens = totalLocked();
    	uint256 currentRewardTokenToUnlock = 0;

    	if(totalLocked() == 0) {
    		unlockedRewardTokens = lockRewardTokens;
    	} else {
    		for(uint256 s = 0; s < rewardSchedule.length; s++) {
	    		RewardSchedule storage schedule = rewardSchedule[s];

	    		
	    		if(now >= schedule.endTimestamp) {
	    			currentRewardTokenToUnlock = schedule.initialLockedToken.sub(schedule.unlockedToken);
	    			schedule.lastUnlockTimestamp = schedule.endTimestamp;
	    		} else {
	    			currentRewardTokenToUnlock = now.sub(schedule.lastUnlockTimestamp)
	    			.mul(schedule.initialLockedToken)
	    			.div(schedule.duration);
	    			schedule.lastUnlockTimestamp = now;
	    		}

	    		schedule.unlockedToken = schedule.unlockedToken.add(currentRewardTokenToUnlock);
    		}

    		unlockedRewardTokens = currentRewardTokenToUnlock.mul(lockRewardTokens).div(totalLocked());
    	}
    	

    	if (unlockedRewardTokens > 0) {
            require(lockedPool.transfer(address(unlockedPool), unlockedRewardTokens),
                'TokenGeyser: transfer out of locked pool failed');
            emit TokensUnlocked(unlockedRewardTokens, totalLocked());
        }

        return unlockedRewardTokens;
    }


    function pause() external onlyAdmin {
    	_pause();
    }

    function unpause() external onlyAdmin {
    	_unpause();
    }

}