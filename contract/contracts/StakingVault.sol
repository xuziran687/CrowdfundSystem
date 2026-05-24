// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IStakingVault.sol";
// 质押合约
contract StakingVault is IStakingVault {
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 rewardPending;
    }

    uint256 public constant REWARD_PER_ETH_PER_DAY = 1e20;
    uint256 public constant REWARD_PRECISION = 1e18;
    uint256 public constant SECONDS_PER_DAY = 86400;

    mapping(address => UserInfo) public users;
    uint256 public override totalETH;
    uint256 private storedTotalR;
    uint256 public accRPerETH;
    uint256 public lastRewardTimestamp;

    address public factory;
    mapping(address => bool) public override isCampaign;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event CampaignRegistered(address indexed campaign);
    event RSpent(address indexed campaign, address indexed user, uint256 amount);
    event FactoryUpdated(address indexed oldFactory, address indexed newFactory);

    constructor() {
        factory = msg.sender;
        lastRewardTimestamp = block.timestamp;
    }

    function _rewardAccrued(uint256 elapsed) internal view returns (uint256) {
        if (elapsed == 0 || totalETH == 0) return 0;
        return (totalETH * elapsed * REWARD_PER_ETH_PER_DAY) / SECONDS_PER_DAY / 1 ether;
    }

    function _currentAccRPerETH() internal view returns (uint256) {
        if (block.timestamp <= lastRewardTimestamp || totalETH == 0) {
            return accRPerETH;
        }
        uint256 reward = _rewardAccrued(block.timestamp - lastRewardTimestamp);
        return accRPerETH + (reward * REWARD_PRECISION) / totalETH;
    }

    function _currentTotalR() internal view returns (uint256) {
        if (block.timestamp <= lastRewardTimestamp || totalETH == 0) {
            return storedTotalR;
        }
        return storedTotalR + _rewardAccrued(block.timestamp - lastRewardTimestamp);
    }

    function _updatePool() internal {
        if (block.timestamp <= lastRewardTimestamp) return;
        if (totalETH == 0) {
            lastRewardTimestamp = block.timestamp;
            return;
        }
        uint256 elapsed = block.timestamp - lastRewardTimestamp;
        uint256 reward = _rewardAccrued(elapsed);
        storedTotalR += reward;
        accRPerETH += (reward * REWARD_PRECISION) / totalETH;
        lastRewardTimestamp = block.timestamp;
    }

    function _updateUser(address user) internal {
        UserInfo storage u = users[user];
        if (u.amount == 0) {
            u.rewardDebt = 0;
            return;
        }
        uint256 accumulated = (u.amount * accRPerETH) / REWARD_PRECISION;
        uint256 pending = accumulated - u.rewardDebt;
        if (pending > 0) {
            u.rewardPending += pending;
        }
        u.rewardDebt = accumulated;
    }

    function userR(address user) public view override returns (uint256) {
        UserInfo storage u = users[user];
        uint256 currentAcc = _currentAccRPerETH();
        uint256 accumulated = (u.amount * currentAcc) / REWARD_PRECISION;
        uint256 pending = accumulated - u.rewardDebt;
        return u.rewardPending + pending;
    }

    function totalR() public view override returns (uint256) {
        return _currentTotalR();
    }

    function stake() external payable {
        require(msg.value > 0, "No ETH sent");
        _updatePool();
        _updateUser(msg.sender);

        UserInfo storage u = users[msg.sender];
        u.amount += msg.value;
        u.rewardDebt = (u.amount * accRPerETH) / REWARD_PRECISION;
        totalETH += msg.value;

        emit Staked(msg.sender, msg.value);
    }

    function unstake(uint256 amount) external {
        require(amount > 0, "Amount zero");
        UserInfo storage u = users[msg.sender];
        require(u.amount >= amount, "Not enough staked");

        _updatePool();
        _updateUser(msg.sender);

        u.amount -= amount;
        u.rewardDebt = (u.amount * accRPerETH) / REWARD_PRECISION;
        totalETH -= amount;

        payable(msg.sender).transfer(amount);
        emit Unstaked(msg.sender, amount);
    }

    function spendR(address user, uint256 amount) external override {
        require(isCampaign[msg.sender], "Not authorized campaign");
        require(amount > 0, "Amount zero");

        _updatePool();
        _updateUser(user);

        UserInfo storage u = users[user];
        require(u.rewardPending >= amount, "R balance not enough");

        u.rewardPending -= amount;
        storedTotalR -= amount;

        emit RSpent(msg.sender, user, amount);
    }

    function registerCampaign(address _campaign) external override {
        require(msg.sender == factory, "Only factory can register");
        isCampaign[_campaign] = true;
        emit CampaignRegistered(_campaign);
    }

    function setFactory(address _factory) external {
        require(msg.sender == factory, "Only factory can set");
        require(_factory != address(0), "Invalid factory");
        emit FactoryUpdated(factory, _factory);
        factory = _factory;
    }
}
