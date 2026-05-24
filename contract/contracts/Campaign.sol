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

    // 状态标志
    bool public finalized;
    bool public success;
    bool public raisedWithdrawn;
    bool public depositWithdrawn;

    // 代币和金库
    ProjectToken public token;
    uint256 public totalToken;
    IStakingVault public vault;

    // 参与者数据
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

    constructor(
        address _creator,
        uint256 _target,
        uint256 _totalToken,
        uint256 _ratio,
        address _vault,
        string memory name,
        string memory symbol
    ) payable {
        require(msg.value > 0, "Need deposit");

        creator = _creator;
        target = _target;
        totalToken = _totalToken;
        maxDeductionRatio = _ratio;
        vault = IStakingVault(_vault);
        token = new ProjectToken(name, symbol, _totalToken);
        deposit = msg.value;
    }
    // 用户质押ETH参与众筹活动
    function pledge() external payable {
        require(!finalized, "Campaign closed");
        require(msg.value > 0, "Need ETH");
        require(msg.sender != creator, "Creator cannot pledge");
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
    // 众筹活动结束
    function finalize() external {
        require(msg.sender == creator, "Not creator");
        require(!finalized, "Already finalized");

        finalized = true;
        success = raised >= target;
        emit Finalized(success);
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
    // 众筹活动失败，用户退回ETH
    function refund() external {
        require(finalized && !success, "Refund unavailable");
        uint256 paid = ethContributed[msg.sender];
        require(paid > 0, "No contribution");

        ethContributed[msg.sender] = 0;
        payable(msg.sender).transfer(paid);
        emit Refunded(msg.sender, paid);
    }
    // 众筹活动结束，众筹ETH退回
    function withdrawRaised() external {
        require(finalized && success, "Withdrawal unavailable");
        require(msg.sender == creator, "Not creator");
        require(!raisedWithdrawn, "Raised already withdrawn");

        raisedWithdrawn = true;
        payable(creator).transfer(raised);
        emit RaisedWithdrawn(raised);
    }  
    // 众筹活动结束，众筹金库退回
    function withdrawDeposit() external {
        require(finalized, "Not finalized");
        require(msg.sender == creator, "Not creator");
        require(!depositWithdrawn, "Deposit already withdrawn");

        depositWithdrawn = true;
        payable(creator).transfer(deposit);
        emit DepositWithdrawn(deposit);
    }
}
