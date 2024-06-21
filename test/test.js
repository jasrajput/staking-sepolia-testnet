const { time } = require('@nomicfoundation/hardhat-network-helpers');
const { expect } = require('chai');
const { ethers, network } = require('hardhat');

const ACCOUNT_IMPERSONATE = "0xbDA5747bFD65F08deb54cb465eB87D40e51B197E";
const POOL_STAKING_ADDRESS = '0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0';
const POOL_DURATION = 30; //DAYS
const LOCK_IN_DURATION = 2; //DAYS
const DISTRIBUTION_AMOUNT = 10000000;
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
          // console.log(provider.toJSON());

          const ethBalance = await ethers.provider.getBalance(ACCOUNT_IMPERSONATE);

          usdtInstance = new ethers.Contract(POOL_STAKING_ADDRESS, USDTABI, ethers.provider);
          
          myContract = await ethers.deployContract('StakingPool');
          // , [POOL_STAKING_ADDRESS, POOL_DURATION, LOCK_IN_DURATION, DISTRIBUTION_AMOUNT]
          await myContract.waitForDeployment();
     });

    
     it('Perform staking and unstaking with calculating reward', async () => {
        const [u1, u2, thirdAccount] = await ethers.getSigners();

        //19 june launched

        // 20 june
        await network.provider.send("evm_increaseTime", [86400]);
        await network.provider.send("evm_mine"); 
        
        const response = await myContract.connect(u1).stake(ethers.parseUnits("1000", 6));
        await response.wait();

        // 22 june
        await network.provider.send("evm_increaseTime", [172800]);
        await network.provider.send("evm_mine");

        //call calculatereward function for user 1
        // const rewards = await myContract.connect(u1).calculateReward(u1, 0);
        // const userRewards = Number(rewards) / 1e6;
        // console.log('1st user reward before 2nd staked: ', userRewards);
        // console.log(' \n');

        const response_ = await myContract.connect(u2).stake(ethers.parseUnits("2000", 6));
        await response_.wait();

        // call calculatereward function for user 1
          // const reward_ = await myContract.connect(u1).calculateReward(u1, 0);
          // const userReward_ = Number(reward_) / 1e6;
          // console.log('1st user reward after 2nd staked: ', userReward_);

        //   const claimedss = await myContract.connect(u1).claimReward();
        // await claimedss.wait();

        

          

        // 23 june
        await network.provider.send("evm_increaseTime", [86400]);
        await network.provider.send("evm_mine");

        const response__ = await myContract.connect(u2).stake(ethers.parseUnits("3000", 6));
        await response__.wait();


        // 24 june
        await network.provider.send("evm_increaseTime", [86400]);
        await network.provider.send("evm_mine");

        const response___ = await myContract.connect(u1).stake(ethers.parseUnits("1000", 6));
        await response___.wait();
        
        //u1 claimed on 25 june
        await network.provider.send("evm_increaseTime", [86400]);
        await network.provider.send("evm_mine");

        // const reward_ = await myContract.connect(u1).calculateReward(u1, 1);
        //   const userReward_ = Number(reward_) / 1e6;
        //   console.log('1st user reward after 2nd staked: ', userReward_);

        const claimed = await myContract.connect(u1).claimReward();
        await claimed.wait();

        // return;

        // 26 june
        await network.provider.send("evm_increaseTime", [86400]);
        await network.provider.send("evm_mine");

        const response____ = await myContract.connect(u2).stake(ethers.parseUnits("3000", 6));
        await response____.wait();
        

        // 27 june u2 unstake
        await network.provider.send("evm_increaseTime", [86400]);
        await network.provider.send("evm_mine");

        const claimeds = await myContract.connect(u2).claimReward();
        await claimeds.wait();

        // const response_____ = await myContract.connect(u2).unstakeTokens(u2);
        // await response_____.wait();
       
     });


    it('Get staker info', async () => {
      const [u1, u2] = await ethers.getSigners();
      // const response = await myContract.connect(u1).getStakerDetails(u1, 0);
      // const response_ = await myContract.connect(u1).getStakerDetails(u1, 1);

      // const responses = await myContract.connect(u2).getStakerDetails(u2, 0);
      // const responsess = await myContract.connect(u2).getStakerDetails(u2, 1);
      // const responsessss = await myContract.connect(u2).getStakerDetails(u2, 2);
      // console.log(Number(response[1]) / 1e6);
      // console.log(Number(response_[1]) / 1e6);

      // console.log('\n');

      // console.log(Number(responses[1]) / 1e6);
      // console.log(Number(responsess[1]) / 1e6);
      // console.log(Number(responsessss[1]) / 1e6);
    });
})
