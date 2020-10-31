pragma solidity >=0.5.0 <=0.6.2;

interface IStaking {

	event Staked(address indexed user, uint256 amount, uint256 total, bytes data);
    event Unstaked(address indexed user, uint256 amount, uint256 total, bytes data);

    function stake(uint256 _amount, bytes calldata _data) external;
    function stakeFor(address _staker, uint256 _amount, bytes calldata _data) external;
    function unstake(uint256 _amount, bytes calldata _data) external;
    function totalStakedFor(address addr) external view returns (uint256);
    function totalStaked() external view returns (uint256);
    function token() external view returns (address);
}