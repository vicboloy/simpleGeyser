pragma solidity >=0.5.0 <=0.6.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SimpleToken is ERC20 {
    uint256 public INITIAL_SUPPLY = 100000000;

	constructor (string memory name, string memory symbol) ERC20(name, symbol) public {
        // Mint 100 tokens to msg.sender
        // Similar to how
        // 1 dollar = 100 cents
        // 1 token = 1 * (10 ** decimals)
        _setupDecimals(9);
        _mint(msg.sender, INITIAL_SUPPLY * (10 ** 9));
    }
}
