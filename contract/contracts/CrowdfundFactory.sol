// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Campaign.sol";
import "./interfaces/IStakingVault.sol";

contract CrowdfundFactory {
    address[] public allCampaigns; // 所有活动合约地址列表，记录工厂创建的所有活动合约地址，确保活动合约的透明度和可追踪性
    address public globalVault; // 全局 StakingVault 地址，所有活动合约共享同一个 StakingVault，确保用户质押和奖励的统一管理和分配
    uint256 public minDeposit; // 最小活动创建押金，确保活动创建者对活动的承诺和责任，同时防止垃圾活动的创建，维护系统的健康发展

    // 活动创建时触发，记录活动合约地址、创建者地址和押金金额，确保活动创建的透明度和可追踪性
    event CampaignCreated(address indexed campaign, address indexed creator, uint256 deposit);

    // 构造函数初始化全局 StakingVault 地址和最小活动创建押金，确保系统的基本配置和安全性
    constructor(address _vault, uint256 _minDeposit) {
        globalVault = _vault;
        minDeposit = _minDeposit;
    }

    // 返回已创建的 Campaign 数量；动态数组 public 不对外暴露 length，供前端按索引安全枚举 allCampaigns，无需 try/catch 试探越界
    function campaignCount() external view returns (uint256) {
        return allCampaigns.length;
    }

    // 创建新的众筹活动，要求提供目标金额、总奖励、兑换比例、活动名称和符号，同时要求支付至少最小押金，确保活动的合理性和创建者的承诺，同时工厂合约会注册新创建的活动合约到 StakingVault 中，确保活动合约的合法性和安全性
    function createCampaign(
        uint256 target,
        uint256 totalToken,
        uint256 ratio,
        string memory name,
        string memory symbol
    ) external payable {
        require(msg.value >= minDeposit, "Deposit required");

        Campaign newCampaign = (new Campaign){value: msg.value}(
            msg.sender,
            target,
            totalToken,
            ratio,
            globalVault,
            name,
            symbol
        );

        address campaignAddr = address(newCampaign);
        allCampaigns.push(campaignAddr);
        IStakingVault(globalVault).registerCampaign(campaignAddr);

        emit CampaignCreated(campaignAddr, msg.sender, msg.value);
    }
}
