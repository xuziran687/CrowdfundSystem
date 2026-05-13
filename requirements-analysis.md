# 需求分析

## 一、背景与目标

本项目旨在搭建一个基于以太坊智能合约的众筹与质押系统，实现以下核心目标：

1. 提供用户质押 ETH 获取奖励的功能。
2. 提供项目发起者创建 Campaign 并募集资金的机制。
3. 保证合约权限与资金安全，确保只有合法主体可执行关键操作。
4. 提供前端 UI 与区块链交互，完成从钱包连接到交易执行的全过程。
5. 支持本地开发与验证，运行在 Hardhat 本地网络上。

## 二、用户角色

### 1. 投资者（普通用户）

- 连接钱包并查看账户余额。
- 将 ETH 存入 Staking Vault 质押，获取系统奖励 R。
- 赎回已质押 ETH。
- 参与 Campaign 认购，使用 ETH 支付并享受 R 抵扣。
- 在 Campaign 失败后申请退款。

### 2. 项目创建者

- 创建新的 Campaign，配置目标资金、项目代币总量、抵扣上限、项目名称和保证金。
- 在 Campaign 达到条件后手动终结 Campaign。
- 项目成功后提取募集资金。
- Campaign 结束后提取保证金。

### 3. 系统管理员/部署者

- 部署 Smart Contract 到本地 Hardhat 网络。
- 初始化 Staking Vault 和 CrowdfundFactory 之间的权限关系。
- 将地址与 ABI 同步到前端。

## 三、功能需求

### 1. Staking Vault 功能

- `stake()`：用户可发送 ETH 质押到金库。 
- `unstake(uint256 amount)`：用户可赎回指定数量 ETH。
- `userR(address)`：查询用户可领取的 R 奖励。
- `totalETH()`：查询金库当前质押总额。
- `totalR()`：查询金库总奖励。
- `registerCampaign(address)`：仅允许工厂注册 Campaign，建立白名单。
- `spendR(address,uint256)`：仅允许白名单 Campaign 销毁用户 R。

### 2. CrowdfundFactory 功能

- `createCampaign(uint256 target, uint256 totalToken, uint256 ratio, string name, string symbol)`：创建新的 Campaign，要求提交保证金。
- 保存所有已创建 Campaign 地址。
- 向 Staking Vault 注册新 Campaign，确保后者可授权执行 R 相关操作。

### 3. Campaign 功能

- `pledge()`：允许用户以 ETH 认购项目，并根据用户 R 余额计算名义贡献。
- `finalize()`：项目创建者手动终结 Campaign，并判断是否成功。
- `claim()`：项目成功后允许用户领取项目代币。
- `refund()`：项目失败后允许用户退回已支付 ETH。
- `withdrawRaised()`：项目成功后由创建者领取募集款。
- `withdrawDeposit()`：Campaign 终结后由创建者取回保证金。

### 4. 前端功能

- 链接本地 Hardhat 钱包。 
- 显示账户 ETH 余额和质押状态。
- 展示 Staking Vault 的总质押与奖励数据。
- 创建 Campaign 并展示工厂地址与 Campaign 列表。
- 查看 Campaign 详情与当前用户参与情况。
- 支持认购、终结、领取、退款、提取募集款、提取保证金等操作。
- 通过 Viem SDK 调用智能合约，同时进行 gas 估算与交易签名。

## 四、性能与质量需求

- 系统应在本地 Hardhat 网络上稳定运行。
- 前端应能正常编译并与合约交互。
- 交易调用应避免出现默认 gas 限制问题，需在执行前进行估算。
- 需要处理读写合约返回值为 undefined 的情况，避免前端崩溃。
- 合约权限操作必须严格校验身份，避免非授权账户执行关键方法。

## 五、约束条件

- 使用 Hardhat 本地网络作为开发与测试环境。
- 前端采用 Vue3 + Vite + Viem 实现。
- 合约语言为 Solidity 0.8.20。
- 仅支持 ETH 质押和 R 奖励机制，当前不涉及跨链或 ERC20 质押。

## 六、风险与问题点

- `StakingVault.factory` 必须与 `CrowdfundFactory` 一致，否则 Campaign 注册失败。
- `Campaign.finalize()` 由创建者手动触发，未自动结算可能导致状态滞后。
- 不正确的 gas 估算参数会导致 writeContract 或 estimateContractGas 失败。
- 奖励展示若误用 ETH 单位格式化函数，可能出现数值非常小的展示结果。
