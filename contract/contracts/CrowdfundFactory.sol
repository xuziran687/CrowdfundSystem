// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Campaign.sol";
import "./interfaces/IStakingVault.sol";
// 众筹工厂
contract CrowdfundFactory {
    address[] public allCampaigns;// 众筹列表
    address public globalVault;
    uint256 public minDeposit;

    event CampaignCreated(address indexed campaign, address indexed creator, uint256 deposit);

    constructor(address _vault, uint256 _minDeposit) {
        globalVault = _vault;
        minDeposit = _minDeposit;
    }

    function campaignCount() external view returns (uint256) {
        return allCampaigns.length;
    }

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
