# 项目分析

## 一、项目概述

本项目是一个基于 Hardhat 的本地以太坊开发环境，包含以下功能模块：
- Staking Vault：用户质押 ETH，获得 R 奖励，并能提取质押或赎回
- CrowdfundFactory / Campaign：创建众筹 Campaign，支持认购、终结、领取、退款、提取募集款和保证金
- 前端：Vue3 + Vite + Viem，实现钱包连接、合约交互和数据展示

## 二、系统架构

### 1. 合约层

- `StakingVault.sol`
  - 负责 ETH 质押、奖励计算、R 余额管理
  - 维护 `factory` 地址和 `isCampaign` 白名单
  - 只有工厂可以注册 Campaign

- `CrowdfundFactory.sol`
  - 创建 Campaign
  - 负责传入保证金并调用 `StakingVault.registerCampaign`
  - 保存已创建 Campaign 地址列表

- `Campaign.sol`
  - 接收用户认购 ETH
  - 计算名义贡献、实际支出和 R 抵扣
  - 由创建者手动 `finalize()` 结束
  - 提供 `claim`、`refund`、`withdrawRaised`、`withdrawDeposit`

### 2. 前端层

- `frontend/src/sdk/contract.js`
  - 存储合约地址和 ABI
  - 通过部署脚本写入前端地址配置

- `frontend/src/sdk/index.js`
  - 封装 Viem contract 读写方法
  - 处理 `walletClient` 与 `publicClient`
  - 增加 gas 估算和 sender（account）字段以避免调用失败

- `frontend/src/components/StakingPanel.vue`
  - 负责质押/赎回和奖励数据展示

- `frontend/src/components/CrowdfundingPanel.vue`
  - 负责 Campaign 创建、选择、认购、终结、领取、退款、提取

## 三、关键问题与修复

### 1. 工厂注册权限问题

- 问题：`Campaign.createCampaign` 调用 `StakingVault.registerCampaign` 时，`StakingVault.factory` 为部署者地址，而不是 `CrowdfundFactory`
- 修复：在 `deploy.js` 部署完成后调用 `vault.setFactory(factoryAddr)`，确保工厂地址正确

### 2. `createCampaign` gas cap 超限

- 问题：默认交易 gas limit 导致 Hardhat 本地节点 `gas cap` 失败
- 修复：在 SDK 中对每个写交易调用 `publicClient.estimateContractGas(...)` 并传入估算值

### 3. `Not creator` 终结失败

- 问题：在 `estimateContractGas` 中没有使用 Viem 正确的 sender 参数，导致估算阶段错误
- 修复：统一将 `from` 改为 `account`，并在 `writeContract` 中保持 `account` 字段

### 4. 奖励显示错误

- 问题：R 奖励使用 `formatEther` 处理，导致实际值被当作 wei 误显示为极小数
- 建议：R 余额应直接使用整数或自定义格式化，不应混用 ETH 单位转换函数

## 四、论文写作建议

### 1. 研究背景

阐述区块链众筹和质押机制在去中心化金融中的应用场景，以及本项目的设计目标。

### 2. 系统设计

详细说明合约模块划分、权限控制、奖励计算、Campaign 结算流程。

### 3. 实现细节

重点描述：
- Solidity 合约函数调用链
- `deploy.js` 部署与地址同步逻辑
- 前端 Viem SDK 与钱包交互

### 4. 问题分析与处理

列举本次调试过程中遇到的核心问题和修复方案，突出“权限校验”和“Gas 估算”两类常见区块链前端问题。

### 5. 运行与验证

描述如何在本地 Hardhat 上运行项目，验证 `createCampaign`、`pledge`、`finalize`、`claim`、`refund`、`withdrawRaised`、`withdrawDeposit` 等流程。

## 五、后续优化方向

- 增加自动 `finalize` 机制或基于时间/目标触发的自动结算
- 完善错误提示和前端状态刷新逻辑
- 支持更多钱包兼容性和网络切换
- R 奖励精度与展示单位统一
