// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStakingVault {
    function totalETH() external view returns (uint256);
    function totalR() external view returns (uint256);
    function userR(address user) external view returns (uint256);
    function isCampaign(address campaign) external view returns (bool);
    function spendR(address user, uint256 amount) external;
    function registerCampaign(address _campaign) external;
}
