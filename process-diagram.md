``` mermaid
flowchart TD
    Start[用户进入 DApp] --> Connect{连接钱包}
    
    %% 投资者路径
    Connect -->|投资者| Dashboard[资产面板: 钱包 ETH / 累计 R]
    Dashboard --> Stake[质押 ETH]
    Stake --> GenerateR[系统根据时间/金额产出 R]
    
    %% 项目方路径
    Connect -->|项目方| Deposit[发起众筹: 需质押保证金 ETH]
    Deposit --> Config[填写参数: 目标额/Token总量/折扣范围]
    Config --> Deploy[自动部署 ProjectToken 合约]
    Deploy --> Create[创建 Campaign 实例]
    Create --> List[展示在众筹列表]

    %% 参与逻辑
    GenerateR -.-> Pledge
    List --> Browse[浏览项目]
    Browse --> Pledge[参与众筹: 输入名义投资额 X]
    Pledge --> Calc[合约计算当前动态折扣 d]
    Calc --> Deduct[R 抵扣: 计算消耗的 R 与需补缴的 ETH]
    Deduct --> Pay[用户支付剩余 ETH]
    Pay --> Record[记录 Contribution 贡献份额]

    %% 结算逻辑
    Record --> Check{筹款结束: 是否达标}
    Check -->|成功| Success[项目方提取 ETH / 用户领取 Token B]
    Check -->|失败| Refund[用户原路退回支付的 ETH]
```