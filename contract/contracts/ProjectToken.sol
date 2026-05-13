// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ProjectToken is ERC20 {
    uint8 private constant DECIMALS = 18;
    
    constructor(
        string memory name,
        string memory symbol,
        uint256 supply
    ) ERC20(name, symbol) {
        _mint(msg.sender, supply * 10**DECIMALS);
    }
    
    function decimals() public view override returns (uint8) {
        return DECIMALS;
    }
}
