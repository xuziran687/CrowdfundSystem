// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ProjectToken.sol";
import "./interfaces/IStakingVault.sol";
import "./MathLogic.sol";
// 众筹活动
contract Campaign {
    // 基本参数
    address public creator;
    uint256 public target;
    uint256 public raised;
    uint256 public totalContribution;
    uint256 public maxDeductionRatio; // BPS (1/10000)
    uint256 public deposit;
    uint256 public deadline; // 截止时间（unix 时间戳）

    // 状态标志
    bool public finalized;
    bool public success;
    bool public raisedWithdrawn;
    bool public depositWithdrawn;
    bool public tokensSwept; // 创建者是否已扫回未领取的代币

    // 代币和金库
    ProjectToken public token;
    uint256 public totalToken;
    IStakingVault public vault;

    // 参与者数据
    address[] public contributors; // 所有贡献者列表（用于失败时自动退款）
    mapping(address => uint256) public contribution;
    mapping(address => uint256) public ethContributed;

    // 折扣计算常量
    uint256 private constant DISCOUNT_D_MIN = 6e17;
    uint256 private constant DISCOUNT_D_MAX = 9e17;
    uint256 private constant DISCOUNT_A_REF = 1000 ether;
    uint256 private constant DISCOUNT_K = 1e18;

    event Pledged(address indexed user, uint256 ethAmount, uint256 discountValue, uint256 nominalContribution);
    event Finalized(bool success);
    event Claimed(address indexed user, uint256 amount);
    event Refunded(address indexed user, uint256 amount);
    event RaisedWithdrawn(uint256 amount);
    event DepositWithdrawn(uint256 amount);
    event TokensSwept(uint256 amount);

    constructor(
        address _creator,
        uint256 _target,
        uint256 _totalToken,
        uint256 _ratio,
        address _vault,
        string memory name,
        string memory symbol,
        uint256 _deadline
    ) payable {
        require(msg.value > 0, "Need deposit");
        require(_deadline > block.timestamp, "Deadline must be in future");

        creator = _creator;
        target = _target;
        totalToken = _totalToken;
        maxDeductionRatio = _ratio;
        vault = IStakingVault(_vault);
        token = new ProjectToken(name, symbol, _totalToken);
        deposit = msg.value;
        deadline = _deadline;
    }
    // 用户质押ETH参与众筹活动
    function pledge() external payable {
        require(!finalized, "Campaign closed");
        require(block.timestamp < deadline, "Campaign expired");
        require(msg.value > 0, "Need ETH");
        require(msg.sender != creator, "Creator cannot pledge");

        // 记录新贡献者（首次参与时加入列表）
        if (ethContributed[msg.sender] == 0) {
            contributors.push(msg.sender);
        }

        // 计算折扣率
        uint256 d = MathLogic.calculateDiscount(
            vault.totalR(),
            vault.totalETH(),
            DISCOUNT_D_MIN,
            DISCOUNT_D_MAX,
            DISCOUNT_A_REF,
            DISCOUNT_K
        );
        // 计算可抵扣的奖励金额
        uint256 maxREquivalent = (vault.userR(msg.sender) * d) / 1e18;
        uint256 maxAllowed = (msg.value * maxDeductionRatio) / 10000;
        uint256 actualREquivalent = maxREquivalent > maxAllowed ? maxAllowed : maxREquivalent;
        // 消耗用户的奖励代币
        if (actualREquivalent > 0) {
            uint256 rToBurn = (actualREquivalent * 1e18) / d;
            vault.spendR(msg.sender, rToBurn);
        }
        // 更新贡献记录
        uint256 nominal = msg.value + actualREquivalent;
        contribution[msg.sender] += nominal;
        ethContributed[msg.sender] += msg.value;
        totalContribution += nominal;
        raised += msg.value;
        emit Pledged(msg.sender, msg.value, actualREquivalent, nominal);
    }
    // 众筹活动结束（创建者可随时结束，截止后任何人都可结束）
    // 失败时尝试自动退款；若 gas 不足，用户可事后调用 claimRefund()
    function finalize() external {
        require(!finalized, "Already finalized");
        require(msg.sender == creator || block.timestamp >= deadline, "Only creator or after deadline");

        finalized = true;
        success = raised >= target;
        emit Finalized(success);

        if (!success) {
            // 尝试自动退款，transfer 失败时不 revert（用户可手动 claimRefund）
            for (uint256 i = 0; i < contributors.length; i++) {
                address addr = contributors[i];
                uint256 paid = ethContributed[addr];
                if (paid > 0) {
                    ethContributed[addr] = 0;
                    contribution[addr] = 0;
                    (bool ok, ) = payable(addr).call{value: paid}("");
                    if (!ok) {
                        // 退款失败，回滚状态让用户自行 claimRefund
                        ethContributed[addr] = paid;
                        contribution[addr] = paid;
                    }
                }
            }
        }
    }

    // 查询是否已过截止时间
    function isExpired() external view returns (bool) {
        return block.timestamp >= deadline;
    }

    // 查询贡献者数量
    function contributorsLength() external view returns (uint256) {
        return contributors.length;
    }
    // 众筹活动成功，用户领取代币
    function claim() external {
        require(finalized && success, "Not success");
        require(msg.sender != creator, "Creator cannot claim");
        uint256 userC = contribution[msg.sender];
        require(userC > 0, "No contribution");
        require(totalContribution > 0, "No total contribution");

        // 计算用户应得的代币数量
        // totalToken 已经是考虑了小数位数的总量 (supply * 10^decimals)
        // userC 和 totalContribution 是以 wei 为单位的 ETH 贡献
        // 所以直接按比例分配代币
        uint256 share = (userC * totalToken) / totalContribution;
        contribution[msg.sender] = 0;
        token.transfer(msg.sender, share);
        emit Claimed(msg.sender, share);
    }
    // 众筹活动失败，用户退回ETH（兼容旧逻辑）
    function refund() external {
        require(finalized && !success, "Refund unavailable");
        uint256 paid = ethContributed[msg.sender];
        require(paid > 0, "No contribution");

        ethContributed[msg.sender] = 0;
        contribution[msg.sender] = 0;
        (bool ok, ) = payable(msg.sender).call{value: paid}("");
        require(ok, "ETH transfer failed");
        emit Refunded(msg.sender, paid);
    }

    // 众筹失败后手动领取退款（pull 模式，解决 finalize 自动退款 gas 不足问题）
    function claimRefund() external {
        require(finalized && !success, "Refund unavailable");
        uint256 paid = ethContributed[msg.sender];
        require(paid > 0, "No ETH to refund");

        ethContributed[msg.sender] = 0;
        contribution[msg.sender] = 0;
        (bool ok, ) = payable(msg.sender).call{value: paid}("");
        require(ok, "ETH transfer failed");
        emit Refunded(msg.sender, paid);
    }
    // 众筹活动结束，众筹金库退回
    function withdrawDeposit() external {
        require(finalized, "Not finalized");
        require(msg.sender == creator, "Not creator");
        require(!depositWithdrawn, "Deposit already withdrawn");

        depositWithdrawn = true;
        (bool ok, ) = payable(creator).call{value: deposit}("");
        require(ok, "ETH transfer failed");
        emit DepositWithdrawn(deposit);
    }

    // 提取募集款（成功后创建者提取）
    function withdrawRaised() external {
        require(finalized && success, "Withdrawal unavailable");
        require(msg.sender == creator, "Not creator");
        require(!raisedWithdrawn, "Raised already withdrawn");

        raisedWithdrawn = true;
        (bool ok, ) = payable(creator).call{value: raised}("");
        require(ok, "ETH transfer failed");
        emit RaisedWithdrawn(raised);
    }

    // 创建者扫回众筹成功后长期无人领取的代币（截止后 90 天）
    function sweepUnclaimedTokens() external {
        require(finalized && success, "Not successful");
        require(msg.sender == creator, "Not creator");
        require(block.timestamp >= deadline + 90 days, "Too early");
        require(!tokensSwept, "Already swept");

        tokensSwept = true;
        uint256 remaining = token.balanceOf(address(this));
        require(remaining > 0, "No tokens left");
        token.transfer(creator, remaining);
        emit TokensSwept(remaining);
    }

    // 接收 ETH（防止 ETH 被锁死）
    receive() external payable {}
    fallback() external payable {}
}
