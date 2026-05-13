// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ProjectToken.sol";
import "./interfaces/IStakingVault.sol";
import "./MathLogic.sol";

contract Campaign {
    address public creator; // 活动创建者地址，记录活动的发起人，确保活动的责任归属和管理，同时在活动结束后可以进行资金和奖励的分配
    uint256 public target; // 众筹目标金额，记录活动的筹资目标，确保活动的合理性和参与者的预期，同时在活动结束后判断活动的成功与否
    uint256 public raised; // 已筹金额，记录活动当前已经筹集的资金总额，确保活动的进展透明和参与者的信心，同时在活动结束后判断活动的成功与否
    uint256 public totalContribution; // 总贡献金额，记录所有参与者的总贡献金额，确保活动的进展透明和参与者的信心，同时在活动结束后用于计算每个参与者的奖励份额
    uint256 public maxDeductionRatio; // 最大抵扣比例（BPS），记录每个参与者在质押奖励时可以抵扣的最大金额占其贡献金额的比例，确保系统的激励机制的合理性和参与者的积极性，同时防止过度抵扣导致活动资金不足
    uint256 public deposit; // 活动创建押金，记录活动创建者在创建活动时支付的押金金额，确保活动创建者对活动的承诺和责任，同时在活动结束后根据活动的成功与否进行押金的退还或没收

    bool public finalized; // 活动是否已结束，记录活动的状态，确保活动的进展透明和参与者的信心，同时在活动结束后禁止进一步的质押和贡献，并根据活动的成功与否进行资金和奖励的分配
    bool public success; // 活动是否成功，记录活动的结果，确保活动的进展透明和参与者的信心，同时在活动结束后根据活动的成功与否进行资金和奖励的分配
    bool public raisedWithdrawn; // 已筹金额是否已提取，记录活动结束后活动创建者是否已经提取了筹集的资金，确保活动的进展透明和参与者的信心，同时在活动结束后根据活动的成功与否进行资金和奖励的分配
    bool public depositWithdrawn; // 押金是否已提取，记录活动结束后活动创建者是否已经提取了押金，确保活动的进展透明和参与者的信心，同时在活动结束后根据活动的成功与否进行资金和奖励的分配

    ProjectToken public token; // 活动发行的项目代币，记录活动的奖励代币，确保活动的激励机制的合理性和参与者的积极性，同时在活动结束后根据每个参与者的贡献金额分配相应数量的代币作为奖励
    uint256 public totalToken; // 活动发行的总代币数量，记录活动的奖励代币总量，确保活动的激励机制的合理性和参与者的积极性，同时在活动结束后根据每个参与者的贡献金额分配相应数量的代币作为奖励
    IStakingVault public vault; // 活动使用的 StakingVault，记录活动使用的质押奖励合约地址，确保活动的激励机制的合理性和参与者的积极性，同时在活动结束后根据每个参与者的贡献金额分配相应数量的代币作为奖励

    mapping(address => uint256) public contribution; // 参与者贡献金额，记录每个参与者的贡献金额，确保活动的进展透明和参与者的信心，同时在活动结束后根据每个参与者的贡献金额分配相应数量的代币作为奖励
    mapping(address => uint256) public ethContributed; // 参与者贡献的ETH金额，记录每个参与者实际支付的ETH金额，确保活动的进展透明和参与者的信心，同时在活动结束后根据每个参与者的贡献金额分配相应数量的代币作为奖励，并在活动失败时退还相应的ETH金额

    // 与 pledge 中原先传入 MathLogic.calculateDiscount 的常量一致，集中命名避免魔法数散落
    uint256 private constant DISCOUNT_D_MIN = 6e17;
    uint256 private constant DISCOUNT_D_MAX = 9e17;
    uint256 private constant DISCOUNT_A_REF = 1000 ether;
    uint256 private constant DISCOUNT_K = 1e18;

    // 参与者质押奖励时触发，记录参与者地址、质押的ETH金额、抵扣的奖励金额和名义贡献金额，确保活动的激励机制的合理性和参与者的积极性，同时在活动结束后根据每个参与者的贡献金额分配相应数量的代币作为奖励
    event Pledged(address indexed user, uint256 ethAmount, uint256 discountValue, uint256 nominalContribution);
    // 活动结束时触发，记录活动是否成功，确保活动的进展透明和参与者的信心，同时在活动结束后根据活动的成功与否进行资金和奖励的分配
    event Finalized(bool success);
    // 参与者领取奖励时触发，记录参与者地址和领取的代币数量，确保活动的激励机制的合理性和参与者的积极性，同时在活动结束后根据每个参与者的贡献金额分配相应数量的代币作为奖励
    event Claimed(address indexed user, uint256 amount);
    // 参与者退款时触发，记录参与者地址和退款金额，确保活动的进展透明和参与者的信心，同时在活动结束后根据活动的成功与否进行资金和奖励的分配
    event Refunded(address indexed user, uint256 amount);
    // 活动创建者提取筹集资金时触发，记录提取金额，确保活动的进展透明和参与者的信心，同时在活动结束后根据活动的成功与否进行资金和奖励的分配
    event RaisedWithdrawn(uint256 amount);
    // 活动创建者提取押金时触发，记录提取金额，确保活动的进展透明和参与者的信心，同时在活动结束后根据活动的成功与否进行资金和奖励的分配
    event DepositWithdrawn(uint256 amount);

    // 构造函数初始化活动的基本信息，包括创建者地址、众筹目标金额、总代币数量、最大抵扣比例、StakingVault 地址和项目代币的名称和符号，同时要求支付押金，确保活动的合理性和创建者的承诺，同时在活动结束后根据活动的成功与否进行资金和奖励的分配
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

    // 参与者质押资金以获得奖励，要求活动未结束且质押金额大于0，同时根据当前 StakingVault 的总奖励和总质押金额计算折扣率，确定参与者可以抵扣的奖励金额，并更新参与者的贡献金额、实际支付的ETH金额和活动的总贡献金额和已筹金额，确保活动的激励机制的合理性和参与者的积极性，同时在活动结束后根据每个参与者的贡献金额分配相应数量的代币作为奖励，并在活动失败时退还相应的ETH金额
    function pledge() external payable {
        require(!finalized, "Campaign closed");
        require(msg.value > 0, "Need ETH");

        uint256 d = MathLogic.calculateDiscount(
            vault.totalR(),
            vault.totalETH(),
            DISCOUNT_D_MIN,
            DISCOUNT_D_MAX,
            DISCOUNT_A_REF,
            DISCOUNT_K
        );

        uint256 maxREquivalent = (vault.userR(msg.sender) * d) / 1e18;
        uint256 maxAllowed = (msg.value * maxDeductionRatio) / 10000;
        uint256 actualREquivalent = maxREquivalent > maxAllowed ? maxAllowed : maxREquivalent;

        if (actualREquivalent > 0) {
            uint256 rToBurn = (actualREquivalent * 1e18) / d;
            vault.spendR(msg.sender, rToBurn);
        }

        uint256 nominal = msg.value + actualREquivalent;
        contribution[msg.sender] += nominal;
        ethContributed[msg.sender] += msg.value;
        totalContribution += nominal;
        raised += msg.value;

        emit Pledged(msg.sender, msg.value, actualREquivalent, nominal);
    }

    // 活动创建者结束活动，要求活动未结束且调用者为创建者，同时根据已筹金额和目标金额判断活动是否成功，并更新活动状态，确保活动的进展透明和参与者的信心，同时在活动结束后根据活动的成功与否进行资金和奖励的分配
    function finalize() external {
        require(msg.sender == creator, "Not creator");
        require(!finalized, "Already finalized");

        finalized = true;
        success = raised >= target;
        emit Finalized(success);
    }

    // 参与者领取奖励，要求活动已结束且成功，同时根据参与者的贡献金额和总贡献金额计算其应得的代币数量，并更新参与者的贡献金额和发放代币，确保活动的激励机制的合理性和参与者的积极性，同时在活动结束后根据每个参与者的贡献金额分配相应数量的代币作为奖励
    function claim() external {
        require(finalized && success, "Not success");
        uint256 userC = contribution[msg.sender];
        require(userC > 0, "No contribution");

        uint256 share = (userC * totalToken) / totalContribution;
        contribution[msg.sender] = 0;
        token.transfer(msg.sender, share);
        emit Claimed(msg.sender, share);
    }

    // 参与者退款，要求活动已结束且失败，同时根据参与者实际支付的ETH金额进行退款，并更新参与者的实际支付金额，确保活动的进展透明和参与者的信心，同时在活动结束后根据活动的成功与否进行资金和奖励的分配
    function refund() external {
        require(finalized && !success, "Refund unavailable");
        uint256 paid = ethContributed[msg.sender];
        require(paid > 0, "No contribution");

        ethContributed[msg.sender] = 0;
        payable(msg.sender).transfer(paid);
        emit Refunded(msg.sender, paid);
    }

    // 活动创建者提取筹集的资金，要求活动已结束且成功，同时确保活动创建者只能提取一次筹集的资金，确保活动的进展透明和参与者的信心，同时在活动结束后根据活动的成功与否进行资金和奖励的分配
    function withdrawRaised() external {
        require(finalized && success, "Withdrawal unavailable");
        require(msg.sender == creator, "Not creator");
        require(!raisedWithdrawn, "Raised already withdrawn");

        raisedWithdrawn = true;
        payable(creator).transfer(raised);
        emit RaisedWithdrawn(raised);
    }

    // 活动创建者提取押金，要求活动已结束且调用者为创建者，同时确保活动创建者只能提取一次押金，确保活动的进展透明和参与者的信心，同时在活动结束后根据活动的成功与否进行资金和奖励的分配
    function withdrawDeposit() external {
        require(finalized, "Not finalized");
        require(msg.sender == creator, "Not creator");
        require(!depositWithdrawn, "Deposit already withdrawn");

        depositWithdrawn = true;
        payable(creator).transfer(deposit);
        emit DepositWithdrawn(deposit);
    }
}
