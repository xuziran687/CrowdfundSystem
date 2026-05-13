// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICrowdfund {
    function pledge() external payable;
    function finalize() external;
    function claim() external;
    function raised() external view returns (uint256);
}
