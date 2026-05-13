// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICrowdfund {
    function pledge() external payable; // 众筹逻辑
    function finalize() external; // 结束众筹逻辑
    function claim() external; // 领取逻辑
    function raised() external view returns (uint256); // 获取当前众筹金额
}
