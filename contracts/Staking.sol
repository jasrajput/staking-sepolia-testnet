// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

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

contract StakingPool is ReentrancyGuard {
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

    struct User {
        uint256 stakedAmount;
        uint256 accumulatedReward;
        uint256 totalReceived;
        uint256 stakedOn;
        uint256 lastUpdatedTime;
        bool isActive;
        uint index;
    }

    mapping(address => User) public users;
    address[] public allStakers;
    address[] public activeStakers;

    event staked(address indexed staker, uint256 amount);
    event rewardClaimed(address indexed user, uint256 amount);
    event unstaked(address indexed unstaker, uint256 amount);

    constructor(
        IERC20 _stakingTokenAddress,
        uint256 _poolDuration,
        uint256 _lockInDuration,
        uint256 _distributionAmount
    ) {
        tokenStakingAddress = _stakingTokenAddress;
        distributionAmount = _distributionAmount * 10**6;
        poolDuration = _poolDuration; 
        lockInDuration = _lockInDuration;
        startTime = block.timestamp;
        
        owner = payable(msg.sender);

        require(_lockInDuration <= _poolDuration, "Lock-in duration cannot be greater than pool duration");
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Permission denied");
        _;
    }

    function stake(uint256 _stakedAmount) external updateReward(msg.sender) returns(bool) {
       require(_stakedAmount > 0, "zero detected");
       require(block.timestamp < startTime.add(poolDuration), "Inactive pool");
    //    IERC20(tokenStakingAddress).transferFrom(msg.sender, owner, _stakedAmount);
       User storage user = users[msg.sender];

       if(!user.isActive) {
         activeStakers.push(msg.sender);
       }

       if(user.stakedAmount == 0) {
          allStakers.push(msg.sender);
          totalUsers++;
          uint lastIndex = allStakers.length - 1;
          user.index = lastIndex;  
       }

       user.isActive = true;
       user.stakedAmount = user.stakedAmount.add(_stakedAmount);
       user.stakedOn = block.timestamp;

       totalStakedAmount = totalStakedAmount.add(_stakedAmount);
       
       emit staked(msg.sender, _stakedAmount);
       return true;
    }

    modifier updateReward(address account) {
        if (account != address(0)) {
            users[account].accumulatedReward = calculateReward(account);
            users[account].lastUpdatedTime = block.timestamp;
        }
        _;
    }

    function calculateReward(address _userAddress) public  view returns (uint) {
        User memory user = users[_userAddress];

        if (totalStakedAmount == 0) {
            return user.accumulatedReward;
        }        

        uint timeElapsed = block.timestamp.sub(user.lastUpdatedTime);
        uint256 dailyTotalDistribution = distributionAmount.div(poolDuration);
        uint256 rewardRate = dailyTotalDistribution / (24 hours);
        uint256 userRewardPerSecond = rewardRate * user.stakedAmount / totalStakedAmount;
        uint256 totalReward = userRewardPerSecond.mul(timeElapsed);
        return totalReward;
    }

    function unstakeTokens(address _account) external updateReward(_account) nonReentrant {
        User memory user = users[_account];
        require(user.isActive, "Please stake first");
        require(block.timestamp >= user.stakedOn.add(lockInDuration), "Time is remaining.Please wait for completion of your staking time.");

        user.stakedAmount = 0;
        user.isActive = false;
        user.stakedOn = 0;

        activeStakers[user.index] = activeStakers[activeStakers.length - 1];
        activeStakers.pop();

        IERC20(tokenStakingAddress).transfer(_account, user.stakedAmount);

        totalUnstaked = totalUnstaked.add(user.stakedAmount);
        totalStakedAmount = totalStakedAmount.sub(user.stakedAmount);
        emit unstaked(_account, user.stakedAmount);
    }

    function claimReward() external updateReward(msg.sender) nonReentrant {
        address unstaker = msg.sender;
        uint remaining = remainingPoolDistribution();
        require(remaining > 0, "Slot full");
        
        User storage user = users[unstaker];
        uint256 amount = user.accumulatedReward;
        require(amount > 0, "No rewards");

        user.accumulatedReward = 0;
        user.totalReceived = user.totalReceived.add(amount);

        // IERC20(tokenStakingAddress).transfer(unstaker, amount);
        totalClaimed = totalClaimed.add(amount);
        emit rewardClaimed(unstaker, amount);
    }

    function getHourlyRewardRate() public view returns(uint)  {
        return distributionAmount.div(poolDuration).div(1 hours);
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

    function getStakerDetails(address _user) public view returns(uint, uint, uint) {
        User memory userInfo = users[_user];
        return (userInfo.stakedAmount, userInfo.totalReceived, userInfo.stakedOn);
    }
    
    function contractStakingInfo() public view returns(uint _totalStaked, uint _distributionAmount, uint _totalUsers, uint _startTime) {
        return (totalStakedAmount, distributionAmount, totalUsers, startTime);
    }

    function countActiveStakers() external view returns(uint) {
        return activeStakers.length;
    }

    function withdraw(uint256 amount) external onlyOwner() {
        IERC20(tokenStakingAddress).transfer(owner, amount);
    }
}