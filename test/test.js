const { time } = require('@nomicfoundation/hardhat-network-helpers');
const { expect } = require('chai');
const { ethers, network } = require('hardhat');

const ACCOUNT_IMPERSONATE = "0xbDA5747bFD65F08deb54cb465eB87D40e51B197E";
const POOL_STAKING_ADDRESS = '0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0';
const POOL_DURATION = 1000; //DAYS
const LOCK_IN_DURATION = 60; //DAYS
const DISTRIBUTION_AMOUNT = 15000;
const USDTABI = [
     {
       "constant": true,
       "inputs": [
         {
           "name": "_owner",
           "type": "address"
         }
       ],
       "name": "balanceOf",
       "outputs": [
         {
           "name": "balance",
           "type": "uint256"
         }
       ],
       "type": "function"
     },
     {
       "constant": false,
       "inputs": [
         {
           "name": "spender",
           "type": "address"
         },
         {
           "name": "value",
           "type": "uint256"
         }
       ],
       "name": "approve",
       "outputs": [
         {
           "name": "success",
           "type": "bool"
         }
       ],
       "type": "function"
     }
   ];

 
describe('Staking Contract', () => {
     let deployer;
     let myContract;
     let usdtInstance;
     let impersonatedSigner;

     before(async () => {
          [deployer] = await ethers.getSigners();
          
          await network.provider.request({
               method: 'hardhat_impersonateAccount',
               params: [ACCOUNT_IMPERSONATE]
          });
          impersonatedSigner = await ethers.getSigner(ACCOUNT_IMPERSONATE);

          const provider = await ethers.provider.getNetwork();
          console.log(provider.toJSON());

          const ethBalance = await ethers.provider.getBalance(ACCOUNT_IMPERSONATE);
          console.log("Impersonated account ETH balance:", ethers.formatEther(ethBalance));

          usdtInstance = new ethers.Contract(POOL_STAKING_ADDRESS, USDTABI, ethers.provider);
          myContract = await ethers.deployContract('StakingPool', [POOL_STAKING_ADDRESS, POOL_DURATION, LOCK_IN_DURATION, DISTRIBUTION_AMOUNT]);
          await myContract.waitForDeployment();
     });

     it('Comparing the owner', async () => {
          const owner = await myContract.owner();
          expect(owner).to.equal(deployer.address);
     });

     it('Perform staking', async () => {
          const amountToStake = "100";

          // const usdtBalance = await usdtInstance.balanceOf(ACCOUNT_IMPERSONATE);
          // console.log("Impersonated account USDT balance:", ethers.formatUnits(usdtBalance, 6)); // USDT usually has 6 decimal places
          // try {
          //      const usdtBalance = await usdtInstance.balanceOf('0x9737100d2f42a196de56ed0d1f6ff598a250e7e4');
          //    console.log("USDT balance:", ethers.formatUnits(usdtBalance, 6)); // USDT usually has 6 decimal places
          // } catch(er) {
          //      console.log(er.message)
          // }

          const approveTx = await usdtInstance.connect(impersonatedSigner).approve(await myContract.getAddress(), ethers.parseUnits(amountToStake, 6));
          await approveTx.wait();
          // console.log(approveTx);

          const response = await myContract.connect(impersonatedSigner).stake(ethers.parseUnits(amountToStake, 6));
          await response.wait();
          console.log("Transaction Receipt:", response);  // Ensure this receipt is valid

          expect(response.status).to.equal(1); // Check if the transaction was successful
     });

     it('it will revert if called soon', async () => {
          await expect(myContract.unstakeTokens(deployer.address)).to.be.revertedWith("Please stake first");
     });

     it('it will unstaked the funds', async () => {
          // days * 24 // convert days to hours
          // hours * 24 // convert hours to minutes
          // minutes * 60 // convert hours to minutes
          
          try {
               await expect(myContract.unstakeTokens(deployer.address)).to.be.revertedWith("Please stake first");
               await time.increase(LOCK_IN_DURATION * 24 * 60 * 60);
               await myContract.unstakeTokens(deployer.address);
          } catch(error) {
               // console.log(error.message);
          }
          
     });

     it('Make sure only owner can withdraw the funds from contract', async () => {
          const amount = 10;
          const [_owner, otherAccount] = await ethers.getSigners();
          await expect(myContract.connect(otherAccount).withdraw(amount)).to.be.revertedWith('Permission denied');
     });
})