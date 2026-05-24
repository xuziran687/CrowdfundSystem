// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// 数学逻辑
library MathLogic {
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
        // 避免 totalR * 1e18 溢出的计算顺序
        uint256 pressure = totalA + 1 == 0 ? totalR : (totalR / (totalA + 1)) * 1e18;
        uint256 factor = (1e18 * 1e18) / (1e18 + (k * pressure) / 1e18);
        uint256 d = (base * factor) / 1e18;
        if (d < dMin) return dMin;
        if (d > dMax) return dMax;
        return d;
    }
}
