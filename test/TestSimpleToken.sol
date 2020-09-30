pragma solidity >=0.4.25 <0.7.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/SimpleToken.sol";

contract TestSimpleToken {

	function testInitialMintedToken() public {
		SimpleToken token = SimpleToken(DeployedAddresses.SimpleToken());

		string memory expected = "ST";

		
		// Assert.equal(token.name(), expected, "Owner should have 100000 SimpleToken initially");
	}
	
}

	