// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
import 'hardhat/console.sol';

interface IERC20{
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;

        return c;
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        _status = NOT_ENTERED;
    }

    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}

abstract contract validateContract {
     function isContract(address addr) internal view returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }
}

contract StakingPool is ReentrancyGuard, validateContract {
    using SafeMath for uint;
    IERC20 public tokenStakingAddress;
    address payable public owner;
    uint256 public totalStakedAmount;
    uint256 public totalClaimed;
    uint256 public totalUnstaked;
    uint256 public totalUsers;

    uint256 public distributionAmount;
    uint256 public poolDuration;
    uint256 public lockInDuration;
    uint256 public startTime;

    struct Deposit {
        uint256 stakedAmount;
        uint256 rewardPerTokenPaid; // It stores the value of rewardPerTokenStored at the time when the user's rewards were last updated or claimed.It helps in calculating how much additional reward a user has earned since the last time their rewards were updated or claimed.
        uint256 accumulatedReward;
        uint256 stakedOn;
        uint256 totalReceived;
    }

    struct User {
        bool isActive;
        uint index;
        uint cycle;
        Deposit[] deposits;
    }

    uint256 lastUpdatedTime;
    uint256 public rewardPerTokenStored; // holds the accumulated rewards per token that have been stored or updated in previous calculations.....keeps track of how much reward (in tokens) each token holder has earned up to the latest update or checkpoint in the contract.
    mapping(address => User) public users; 
    address[] public allStakers;
    address[] public activeStakers;

    event staked(address indexed staker, uint256 amount);
    event rewardClaimed(address indexed user, uint256 amount);
    event unstaked(address indexed unstaker, uint256 amount);

    constructor(
        // IERC20 _stakingTokenAddress,
        // uint256 _poolDuration,
        // uint256 _lockInDuration,
        // uint256 _distributionAmount
    ) {
        // tokenStakingAddress = _stakingTokenAddress;
        // distributionAmount = _distributionAmount * 10**6;
        // poolDuration = _poolDuration; 
        // lockInDuration = _lockInDuration;

        tokenStakingAddress = IERC20(0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0);
        distributionAmount = 10000000 * 10**6;
        poolDuration = 30;
        lockInDuration = 2;
        startTime = block.timestamp;
        lastUpdatedTime = block.timestamp;

        require(!isContract(msg.sender), "Owner cannot be a contract");
        owner = payable(msg.sender);
        // require(_lockInDuration <= _poolDuration, "Lock-in duration cannot be greater than pool duration");
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Permission denied");
        _;
    }

    function stake(uint256 _stakedAmount) external updateReward(msg.sender) returns(bool) {
       require(_stakedAmount > 0, "zero detected");
       require(block.timestamp < startTime.add(poolDuration * 1 days), "Inactive pool");
    //    IERC20(tokenStakingAddress).transferFrom(msg.sender, owner, _stakedAmount);
       User storage user = users[msg.sender];

       if(!user.isActive) {
         activeStakers.push(msg.sender);
       }

       if(user.deposits.length == 0) {
          allStakers.push(msg.sender);
          totalUsers++;
          uint lastIndex = allStakers.length - 1;
          user.index = lastIndex;  
       }

       user.isActive = true;
       totalStakedAmount = totalStakedAmount.add(_stakedAmount);

       user.deposits.push(Deposit({
            stakedAmount: _stakedAmount,
            rewardPerTokenPaid: rewardPerTokenStored,
            accumulatedReward: 0,
            stakedOn: block.timestamp,
            totalReceived: 0
        }));


       user.cycle++;

       lastUpdatedTime = block.timestamp;

       emit staked(msg.sender, _stakedAmount);
       return true;
    }

    function updateAccumulatedRewards(address userAddress) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdatedTime = block.timestamp;

        User storage user = users[userAddress];
        for (uint256 i = 0; i < user.deposits.length; i++) {
            Deposit storage deposit = user.deposits[i];
            deposit.accumulatedReward = calculateReward(userAddress, i);
            deposit.rewardPerTokenPaid = rewardPerTokenStored;
        }
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStakedAmount == 0) {
            return rewardPerTokenStored;
        }

        uint256 dailyTotalDistribution = distributionAmount.div(poolDuration); //333333333333 =  333333.333
        uint256 rewardRatePerSecond = dailyTotalDistribution.div(24 hours); // tokens per second 3858024.69 =  3.858
        uint256 timeElapsed = block.timestamp - lastUpdatedTime;

        return rewardPerTokenStored + (rewardRatePerSecond.mul(timeElapsed).mul(1e6).div(totalStakedAmount));
    }

    function calculateReward(address account, uint256 depositIndex) public view returns (uint256) {
        User storage user = users[account];
        Deposit storage deposit = user.deposits[depositIndex];
        console.log("rewardPerTokenStored: ", rewardPerToken());
        return deposit.stakedAmount * (rewardPerToken() - deposit.rewardPerTokenPaid) / 1e6 + deposit.accumulatedReward;
    }

    modifier updateReward(address account) {
        if (account != address(0)) {
            updateAccumulatedRewards(account);
        }
        _;
    }

    function unstakeTokens(address _account, uint256 _index) external updateReward(_account) nonReentrant {
        User storage user = users[_account];
        Deposit storage deposit = user.deposits[_index];
        require(user.isActive, "Please stake first");

        require(block.timestamp >= deposit.stakedOn.add(lockInDuration * 1 days), "Time is remaining.Please wait for completion of your staking time.");

        user.isActive = false;

        if(user.deposits.length == 1) {
            activeStakers[user.index] = activeStakers[activeStakers.length - 1];
            activeStakers.pop();
        }

        // IERC20(tokenStakingAddress).transfer(_account, user.stakedAmount);
        totalUnstaked = totalUnstaked.add(deposit.stakedAmount);
        totalStakedAmount = totalStakedAmount.sub(deposit.stakedAmount);

        deposit.stakedAmount = 0;
        deposit.stakedOn = 0;

        emit unstaked(_account, deposit.stakedAmount);
    }


    function claimReward() external updateReward(msg.sender) nonReentrant {
        address unstaker = msg.sender;
        uint remaining = remainingPoolDistribution();
        require(remaining > 0, "Slot full");
        uint256 amount;
        
        User storage user = users[unstaker];

        for(uint256 i = 0; i < user.deposits.length; i++) {
            amount = amount.add(user.deposits[i].accumulatedReward);
            user.deposits[i].totalReceived = user.deposits[i].totalReceived.add(user.deposits[i].accumulatedReward);
            user.deposits[i].accumulatedReward = 0;
        }

        require(amount > 0, "No rewards");
        
        // IERC20(tokenStakingAddress).transfer(unstaker, amount);
        totalClaimed = totalClaimed.add(amount);
        emit rewardClaimed(unstaker, amount);
    }

    function getHourlyRewardRate() public view returns(uint)  {
        return distributionAmount.div(poolDuration).div(24).div(1e6);
    }

    function remainingPoolDistribution() public view returns(uint) {
        if(distributionAmount > totalClaimed) {
            return distributionAmount.sub(totalClaimed);
        }

        return 0;
    }

    function getStakersList() public view returns(address[] memory) {
        return allStakers;
    }

    function getActiveStakersList() public view returns(address[] memory) {
        return activeStakers;
    }

    function getStakerDetails(address _user, uint256 _index) public view returns(uint amount, uint received, uint stakedDate, uint accumulativeReward) {
        User memory user = users[_user];
        return (user.deposits[_index].stakedAmount, user.deposits[_index].totalReceived, user.deposits[_index].stakedOn, user.deposits[_index].accumulatedReward);
    }
    
    function contractStakingInfo() public view returns(uint _totalStaked, uint _distributionAmount, uint _totalUsers, uint _startTime) {
        return (totalStakedAmount, distributionAmount, totalUsers, startTime);
    }

    function countActiveStakers() external view returns(uint) {
        return activeStakers.length;
    }

    function getUserTotalStakes(address _userAddress) public view returns (uint256 amount) {
        for(uint256 i = 0; i < users[_userAddress].deposits.length; i++) {
            amount = amount.add(users[_userAddress].deposits[i].stakedAmount);
        }
    }

    function withdraw(uint256 amount) external onlyOwner() {
        IERC20(tokenStakingAddress).transfer(owner, amount);
    }
}
