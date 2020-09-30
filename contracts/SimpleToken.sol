pragma solidity >=0.5.0 <=0.5.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SimpleToken is ERC20 {
    string public name = "SimpleToken";
    string public symbol = "ST";
    uint256 public decimals = 9;
    uint256 public INITIAL_SUPPLY = 100000000;


    constructor() public {
        _mint(msg.sender, INITIAL_SUPPLY * (10 ** decimals));
    }
}
