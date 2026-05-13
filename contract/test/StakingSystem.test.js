const { time, loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("StakingSystem", function () {
  // 测试用例
  async function deployStakingFixture() {
    const [owner, user] = await ethers.getSigners();

    // 1. 部署两个简单的 ERC20 代币作为质押币和奖励币
    const Token = await ethers.getContractFactory("ERC20Mock"); // 你需要一个 Mock 代币合约
    const stakingToken = await Token.deploy("Staking Token", "STK", owner.address, ethers.parseEther("10000"));
    const rewardToken = await Token.deploy("Reward Token", "RWD", owner.address, ethers.parseEther("10000"));

    // 2. 部署质押合约
    const StakingSystem = await ethers.getContractFactory("StakingSystem");
    const stakingSystem = await StakingSystem.deploy(stakingToken.target, rewardToken.target);

    // 3. 给奖励合约注入奖励币
    await rewardToken.transfer(stakingSystem.target, ethers.parseEther("1000"));

    // 4. 给用户发送质押币并授权
    await stakingToken.transfer(user.address, ethers.parseEther("100"));
    await stakingToken.connect(user).approve(stakingSystem.target, ethers.parseEther("100"));

    return { stakingSystem, stakingToken, rewardToken, owner, user };
  }
  // 测试质押
  it("用户质押一天后应该获得正确的奖励", async function () {
    const { stakingSystem, user } = await loadFixture(deployStakingFixture);

    const stakeAmount = ethers.parseEther("10");
    await stakingSystem.connect(user).stake(stakeAmount);

    // --- 核心测试逻辑：快进时间 ---
    // 快进 86400 秒 (1天)
    await time.increase(86400);

    const earned = await stakingSystem.earned(user.address);
    
    // 预期收益 = 1(rewardRate) * 86400(秒) = 86400 Token
    // 注意：合约里 rewardRate 设的是 1e18，所以单位是秒产1个
    expect(earned).to.equal(ethers.parseEther("86400"));
  });
  // 测试领取奖励
  it("领取奖励后余额应该增加", async function () {
    const { stakingSystem, rewardToken, user } = await loadFixture(deployStakingFixture);

    await stakingSystem.connect(user).stake(ethers.parseEther("10"));
    await time.increase(100);

    const initialBalance = await rewardToken.balanceOf(user.address);
    await stakingSystem.connect(user).getReward();
    const finalBalance = await rewardToken.balanceOf(user.address);

    expect(finalBalance).to.be.gt(initialBalance);
  });
});