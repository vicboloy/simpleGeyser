pragma solidity ^0.6.2;

import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

contract GeyserProxyFactory is TransparentUpgradeableProxy {
  address public owner;
  address public impl;

  constructor(address _implementation, address _admin, bytes memory _data) public payable TransparentUpgradeableProxy(_implementation, _admin, _data) {
    owner = _admin;
    impl = _implementation;
  }
}