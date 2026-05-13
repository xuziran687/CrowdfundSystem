// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IStakingVault.sol";

contract StakingVault is IStakingVault {
    struct UserInfo {
        uint256 amount; // 用户质押金额，记录用户当前质押的ETH数量，确保用户的质押状态的准确记录和管理
        uint256 rewardDebt; // 奖励债务，记录用户已经计算过的奖励部分，确保用户奖励的正确计算和分配，避免重复计算同一部分奖励
        uint256 rewardPending; // 待领取奖励，记录用户当前未领取的奖励金额，确保用户可以看到他们的总奖励余额，并在领取时正确发放奖励
    }

    uint256 public constant REWARD_PER_ETH_PER_DAY = 1e20; // 每ETH每天的奖励，单位为R，确保奖励分配的合理性和系统的激励机制
    uint256 public constant REWARD_PRECISION = 1e18; // 奖励精度，乘以这个值来保持奖励计算的精度，确保用户奖励余额的正确显示和计算
    uint256 public constant SECONDS_PER_DAY = 86400; // 一天的秒数，用于按时间比例计算奖励

    mapping(address => UserInfo) public users; // 用户信息映射，记录每个用户的质押金额、奖励债务和待领取奖励，确保用户的质押和奖励状态的准确记录和管理
    uint256 public override totalETH; // 总质押金额，记录所有用户的质押总额，确保奖励分配的准确性和系统的整体状态的透明度
    uint256 private storedTotalR; // 存储的总奖励，包含了用户已累积的奖励和当前未发放的奖励，确保用户可以看到他们的总奖励余额
    uint256 public accRPerETH; // 累计每ETH的奖励，乘以 REWARD_PRECISION 来保持精度，确保奖励计算的准确性和用户奖励余额的正确显示
    uint256 public lastRewardTimestamp; // 上次更新奖励的时间戳，确保奖励计算的正确性和及时性

    address public factory; // 工厂合约地址，只有工厂合约可以注册活动合约和更新 StakingVault 的地址，确保系统的安全性和可维护性
    mapping(address => bool) public override isCampaign; // 记录被授权的活动合约地址，确保只有合法的活动合约才能调用 spendR 函数来扣除用户的奖励余额

    event Staked(address indexed user, uint256 amount); // 用户质押时触发，记录用户地址和质押金额，确保质押活动的透明度和可追踪性
    event Unstaked(address indexed user, uint256 amount); // 用户取款时触发，记录用户地址和取款金额，确保取款活动的透明度和可追踪性
    event CampaignRegistered(address indexed campaign); // 活动合约注册时触发，记录活动合约地址，确保活动合约的合法性和安全性
    // 活动合约扣除用户奖励时触发，记录活动合约地址、用户地址和扣除金额，确保奖励使用的透明度和可追踪性
    event RSpent(address indexed campaign, address indexed user, uint256 amount);
    // 工厂合约可以更新 StakingVault 的地址，以便在需要时进行升级或替换，确保系统的可维护性和灵活性
    event FactoryUpdated(address indexed oldFactory, address indexed newFactory);

    // 构造函数初始化工厂地址和上次奖励时间，确保奖励计算的正确性和及时性
    constructor() {
        factory = msg.sender;
        lastRewardTimestamp = block.timestamp;
    }

    // 自上次记账以来、在「当前 totalETH 不变」假设下应新产生的 R 数量（供视图与 _updatePool 共用，避免同一公式写三遍）
    function _rewardAccrued(uint256 elapsed) internal view returns (uint256) {
        if (elapsed == 0 || totalETH == 0) return 0;
        return (totalETH * elapsed * REWARD_PER_ETH_PER_DAY) / SECONDS_PER_DAY / 1 ether;
    }

    // 当前每ETH的累计奖励（视图路径，不落盘）
    function _currentAccRPerETH() internal view returns (uint256) {
        if (block.timestamp <= lastRewardTimestamp || totalETH == 0) {
            return accRPerETH;
        }
        uint256 reward = _rewardAccrued(block.timestamp - lastRewardTimestamp);
        return accRPerETH + (reward * REWARD_PRECISION) / totalETH;
    }

    // totalR 视图：包含尚未写入 storedTotalR 的时间增量部分
    function _currentTotalR() internal view returns (uint256) {
        if (block.timestamp <= lastRewardTimestamp || totalETH == 0) {
            return storedTotalR;
        }
        return storedTotalR + _rewardAccrued(block.timestamp - lastRewardTimestamp);
    }

    // 更新全局奖励状态：计算自上次更新以来的奖励，并更新累计每ETH奖励和总奖励
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

    // 用户记账：把应计入 rewardPending 的部分结算进用户状态，并同步 rewardDebt
    function _updateUser(address user) internal {
        UserInfo storage u = users[user];
        if (u.amount == 0) {
            // 与原先 (u.amount * accRPerETH) / REWARD_PRECISION 在 amount==0 时等价
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

    // userR：用户当前可见的 R 余额（含待结算增量）
    function userR(address user) public view override returns (uint256) {
        UserInfo storage u = users[user];
        uint256 currentAcc = _currentAccRPerETH();
        uint256 accumulated = (u.amount * currentAcc) / REWARD_PRECISION;
        uint256 pending = accumulated - u.rewardDebt;
        return u.rewardPending + pending;
    }

    // totalR：全局 R 总量视图
    function totalR() public view override returns (uint256) {
        return _currentTotalR();
    }

    // 用户质押：先更新池与用户，再增加质押并同步 debt
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

    // 用户赎回：先更新池与用户，再减少质押并转账 ETH
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

    // 仅已注册 Campaign 可调用：从用户待领取 R 中扣除，并减少全局 storedTotalR
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

    // 仅工厂：将新 Campaign 登记为可 spendR 的合约
    function registerCampaign(address _campaign) external override {
        require(msg.sender == factory, "Only factory can register");
        isCampaign[_campaign] = true;
        emit CampaignRegistered(_campaign);
    }

    // 仅工厂：更换工厂地址（用于升级或迁移）
    function setFactory(address _factory) external {
        require(msg.sender == factory, "Only factory can set");
        require(_factory != address(0), "Invalid factory");
        emit FactoryUpdated(factory, _factory);
        factory = _factory;
    }
}
