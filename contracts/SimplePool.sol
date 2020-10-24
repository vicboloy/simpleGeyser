pragma solidity >=0.5.0 <=0.6.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";

import "./AccessRule.sol";

/**
 * @title A simple holder of tokens.
 * This is a simple contract to hold tokens. It's useful in the case where a separate contract
 * needs to hold multiple distinct pools of the same token.
 */
contract SimplePool is AccessRule {
    IERC20 public token;

    function initialize(IERC20 _token, address _adminAccount) public initializer {
        AccessRule.initialize(_adminAccount);
        token = _token;
    }

    function balance() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function transfer(address to, uint256 value) external onlyAdmin returns (bool)  {
        return token.transfer(to, value);
    }
}