const SimpleToken = artifacts.require("SimpleToken");

contract('SimpleToken', (accounts) => {
  	it('should put 100000 SimpleToken in the first account', async () => {
    	const simpleTokenInstance = await SimpleToken.deployed();
    	const balance = await simpleTokenInstance.balanceOf(accounts[0]);

    	assert.equal(balance.valueOf(), 100000, "100000 wasn't in the first account");
  	});
  	it('should have 100000 Simpletoken supply initially', async () => {
  		const simpleTokenInstance = await SimpleToken.deployed();
  		const totalSupply = await simpleTokenInstance.totalSupply();

  		assert.equal(totalSupply, 100000, "Initial total supply of SimpleToken is not equal to 100000");
  	});
});
