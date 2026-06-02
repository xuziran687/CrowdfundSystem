// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IStakingVault.sol";
// 质押合约
contract StakingVault is IStakingVault {
    struct UserInfo {
        uint256 amount;              // 用户质押的ETH数量
        uint256 rewardDebt;          // 用户奖励债务（用于计算用户应得奖励）
        uint256 rewardPending;       // 用户待领取奖励
    }

    uint256 public constant REWARD_PER_ETH_PER_DAY = 1e20;  // 每天每ETH的奖励数量
    uint256 public constant REWARD_PRECISION = 1e18;        // 奖励计算精度
    uint256 public constant SECONDS_PER_DAY = 86400;        // 每天秒数

    mapping(address => UserInfo) public users;               // 用户信息映射
    uint256 public override totalETH;                        // 总质押ETH数量
    uint256 private storedTotalR;                            // 存储的总R奖励
    uint256 public accRPerETH;                               // 每ETH累计R奖励
    uint256 public lastRewardTimestamp;                      // 上次奖励计算时间戳

    address public factory;                                  // 工厂合约地址
    mapping(address => bool) public override isCampaign;     // 是否为有效的众筹活动

    event Staked(address indexed user, uint256 amount);                // 质押事件
    event Unstaked(address indexed user, uint256 amount);              // 解质押事件
    event CampaignRegistered(address indexed campaign);                // 众筹活动注册事件
    event RSpent(address indexed campaign, address indexed user, uint256 amount);  // R奖励消耗事件
    event FactoryUpdated(address indexed oldFactory, address indexed newFactory);   // 工厂更新事件

    constructor() {
        factory = msg.sender;
        lastRewardTimestamp = block.timestamp;
    }
    
    // 计算经过指定时间后产生的奖励
    // elapsed 经过的时间（秒）
    // 返回产生的奖励数量
    function _rewardAccrued(uint256 elapsed) internal view returns (uint256) {
        if (elapsed == 0 || totalETH == 0) return 0;
        return (totalETH * elapsed * REWARD_PER_ETH_PER_DAY) / SECONDS_PER_DAY / 1 ether;
    }

    // 计算当前每ETH的累计奖励
    // 当前每ETH的累计奖励
    function _currentAccRPerETH() internal view returns (uint256) {
        if (block.timestamp <= lastRewardTimestamp || totalETH == 0) {
            return accRPerETH;
        }
        uint256 reward = _rewardAccrued(block.timestamp - lastRewardTimestamp);
        return accRPerETH + (reward * REWARD_PRECISION) / totalETH;
    }

    // 计算当前总奖励
    // 当前总奖励数量
    function _currentTotalR() internal view returns (uint256) {
        if (block.timestamp <= lastRewardTimestamp || totalETH == 0) {
            return storedTotalR;
        }
        return storedTotalR + _rewardAccrued(block.timestamp - lastRewardTimestamp);
    }

    // 更新奖励池状态
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

    // 更新特定用户的信息
    // user 用户地址
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

    // 查询用户可获得的R奖励
    // user 用户地址
    // 用户可获得的R奖励数量
    function userR(address user) public view override returns (uint256) {
        UserInfo storage u = users[user];
        uint256 currentAcc = _currentAccRPerETH();
        uint256 accumulated = (u.amount * currentAcc) / REWARD_PRECISION;
        uint256 pending = accumulated - u.rewardDebt;
        return u.rewardPending + pending;
    }

    // 查询总R奖励
    // 总R奖励数量
    function totalR() public view override returns (uint256) {
        return _currentTotalR();
    }

    // 用户质押ETH
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

    // 用户解质押ETH
    // amount 解质押的数量
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

    // 众筹活动消耗用户的R奖励
    // user 用户地址
    // amount 消耗的R奖励数量
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

    // 注册新的众筹活动
    // _campaign 众筹活动合约地址
    function registerCampaign(address _campaign) external override {
        require(msg.sender == factory, "Only factory can register");
        isCampaign[_campaign] = true;
        emit CampaignRegistered(_campaign);
    }

    // 设置新的工厂合约地址
    // _factory 新工厂合约地址
    function setFactory(address _factory) external {
        require(msg.sender == factory, "Only factory can set");
        require(_factory != address(0), "Invalid factory");
        emit FactoryUpdated(factory, _factory);
        factory = _factory;
    }
}