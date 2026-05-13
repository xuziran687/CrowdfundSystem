// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStakingVault {
    function totalETH() external view returns (uint256); // 获取总 ETH
    function totalR() external view returns (uint256); // 获取总 R
    function userR(address user) external view returns (uint256); // 获取用户 R
    function isCampaign(address campaign) external view returns (bool); // 判断是否是 factory 登记的 Campaign
    function spendR(address user, uint256 amount) external; // 销毁 R
    function registerCampaign(address _campaign) external; // 仅限工厂登记的 Campaign 销毁 R
}
