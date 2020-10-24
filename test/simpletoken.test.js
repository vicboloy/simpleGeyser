// test/Box.proxy.test.js
// Load dependencies
const { expect } = require('chai');
const { deployProxy, upgradeProxy} = require('@openzeppelin/truffle-upgrades');
 
// Load compiled artifacts
const SimpleToken = artifacts.require('SimpleToken');
const SimplePool = artifacts.require('SimplePool');
 
// Start test block
contract('SimplePool (proxy)', function () {
 
  beforeEach(async function () {
    // Deploy a new Box contract for each test
    this.simpleToken = await SimpleToken.new("Simple Token", "ST");
    this.simplePool = await deployProxy(SimplePool, [this.simpleToken.address, this.simpleToken.address], {initializer: 'initialize'});
  });
 
  // Test case
  it('retrieve returns a value previously incremented', async function () {
    // Increment
    // await this.boxV2.increment();
 
    // Test if the returned value is the same one
    // Note that we need to use strings to compare the 256 bit integers
    // expect((await this.boxV2.retrieve()).toString()).to.equal('43');
  });
});