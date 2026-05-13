// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library MathLogic {
    // 计算折扣率，基于总奖励、总质押金额、最小折扣率、最大折扣率、参考质押金额和压力系数，确保系统的动态定价机制和激励机制的合理性
    function calculateDiscount(
        uint256 totalR,
        uint256 totalA,
        uint256 dMin,
        uint256 dMax,
        uint256 Aref,
        uint256 k
    ) internal pure returns (uint256) {
        uint256 denomA = totalA + Aref;
        if (denomA == 0) denomA = 1;
        uint256 base = dMin + (dMax - dMin) * Aref / denomA;

        uint256 pressure = (totalR * 1e18) / (totalA + 1);
        uint256 factor = (1e18 * 1e18) / (1e18 + (k * pressure) / 1e18);
        uint256 d = (base * factor) / 1e18;

        if (d < dMin) return dMin;
        if (d > dMax) return dMax;
        return d;
    }
}
