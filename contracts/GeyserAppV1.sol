pragma solidity >=0.5.0 <=0.6.2;

import "./GeyserApp.sol";

contract GeyserAppV1 is GeyserApp {
	string public version;

	function getVersion() public view returns (string memory) {
		return version;
	}

	function setVersion(string memory _newVersion) public {
		version = _newVersion;
	}
}