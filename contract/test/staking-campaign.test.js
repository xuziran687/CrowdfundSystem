const { expect } = require("chai");

describe("质押 + 众筹 全流程端到端测试", function () {
  it("应实现：用户质押奖励、R 折扣抵扣、众筹结算及代币领取", async function () {
    const [deployer, alice, bob, project] = await ethers.getSigners();

    // 1. 部署金库
    const StakingVault = await ethers.getContractFactory("StakingVault", deployer);
    const vault = await StakingVault.deploy();
    await vault.waitForDeployment();
    console.log("✅ StakingVault (质押金库) 部署成功，地址:", vault.target);

    // 2. 部署工厂
    const CrowdfundFactory = await ethers.getContractFactory("CrowdfundFactory", deployer);
    const factory = await CrowdfundFactory.deploy(vault.target, ethers.parseEther("0.01"));
    await factory.waitForDeployment();
    console.log("✅ CrowdfundFactory (项目工厂) 部署成功，地址:", factory.target);

    // 3. 权限关联
    const setFactoryTx = await vault.setFactory(factory.target);
    await setFactoryTx.wait();
    console.log("🔗 已将 StakingVault 的工厂地址更新为 CrowdfundFactory");

    // 4. 发起项目
    const createTx = await factory.connect(project).createCampaign(
      ethers.parseEther("1"), // 目标 1 ETH
      1000,                  // 1000 代币
      3000,                  // 最高抵扣 30% (BPS: 3000)
      "演示项目",
      "DPR",
      { value: ethers.parseEther("0.02") } // 质押保证金
    );
    await createTx.wait();
    console.log("🚀 项目方已成功发起众筹:", project.address);

    const campaignAddress = await factory.allCampaigns(0);
    console.log("📍 众筹项目合约地址:", campaignAddress);

    const Campaign = await ethers.getContractFactory("Campaign", deployer);
    const campaign = Campaign.attach(campaignAddress);

    // 5. Alice 进行质押
    const aliceStakeTx = await vault.connect(alice).stake({ value: ethers.parseEther("1") });
    await aliceStakeTx.wait();
    console.log("💰 Alice 质押了 1 ETH 到金库中");

    // 6. 模拟时间流逝（产生 R 收益）
    await ethers.provider.send("evm_increaseTime", [24 * 3600]);
    await ethers.provider.send("evm_mine", []);
    console.log("⏳ 模拟时间流逝 1 天，以累积 R 权益");

    const aliceRBefore = await vault.userR(alice.address);
    console.log("📊 投资前 Alice 的 R 余额:", aliceRBefore.toString());
    expect(aliceRBefore).to.be.gt(0);

    // 7. Alice 参与众筹（使用折扣）
    const alicePledgeTx = await campaign.connect(alice).pledge({ value: ethers.parseEther("0.8") });
    await alicePledgeTx.wait();
    console.log("🎟️ Alice 支付 0.8 ETH 参与众筹（使用了 R 折扣），交易哈希:", alicePledgeTx.hash);

    const aliceRAfter = await vault.userR(alice.address);
    console.log("📉 投资后 Alice 的 R 余额 (应减少):", aliceRAfter.toString());
    expect(aliceRAfter).to.be.lt(aliceRBefore);

    const aliceContribution = await campaign.contribution(alice.address);
    const aliceEthContribution = await campaign.ethContributed(alice.address);
    console.log("💎 Alice 的名义贡献度 (含折扣额):", ethers.formatEther(aliceContribution));
    console.log("💵 Alice 实际支付的 ETH:", ethers.formatEther(aliceEthContribution));
    expect(aliceEthContribution).to.equal(ethers.parseEther("0.8"));

    // 8. Bob 参与众筹（无折扣直投）
    const bobPledgeTx = await campaign.connect(bob).pledge({ value: ethers.parseEther("1") });
    await bobPledgeTx.wait();
    console.log("🏃 Bob 支付 1 ETH 直接参与众筹（无 R 折扣）");

    // 9. 结算众筹
    const finalizeTx = await campaign.connect(project).finalize();
    await finalizeTx.wait();
    console.log("🏁 众筹已结束。成功状态:", await campaign.success());

    // 10. 领取回报
    const tokenAddress = await campaign.token();
    const ProjectToken = await ethers.getContractFactory("ProjectToken", deployer);
    const projectToken = ProjectToken.attach(tokenAddress);

    await campaign.connect(alice).claim();
    console.log("🎁 Alice 已领取项目代币");

    await campaign.connect(bob).claim();
    console.log("🎁 Bob 已领取项目代币");

    const aliceTokenBalance = await projectToken.balanceOf(alice.address);
    const bobTokenBalance = await projectToken.balanceOf(bob.address);
    console.log("📈 Alice 最终代币余额:", aliceTokenBalance.toString());
    console.log("📈 Bob 最终代币余额:", bobTokenBalance.toString());

    // 验证：Alice虽然投的ETH少，但因为折扣，应该能领到相对于其“名义贡献”的代币
    expect(aliceTokenBalance).to.be.gt(0);
    expect(bobTokenBalance).to.be.gt(0);

    // 11. 项目方提取资金
    await campaign.connect(project).withdrawRaised();
    console.log("💸 项目发起者已提取筹集的 ETH 资金");

    await campaign.connect(project).withdrawDeposit();
    console.log("🔓 项目发起者已取回初始保证金");
  });

  it("众筹失败时：应允许投资者申请退款", async function () {
    const [deployer, bob, project] = await ethers.getSigners();

    const StakingVault = await ethers.getContractFactory("StakingVault", deployer);
    const vault = await StakingVault.deploy();
    await vault.waitForDeployment();

    const CrowdfundFactory = await ethers.getContractFactory("CrowdfundFactory", deployer);
    const factory = await CrowdfundFactory.deploy(vault.target, ethers.parseEther("0.01"));
    await factory.waitForDeployment();

    await vault.setFactory(factory.target);

    // 发起一个目标极高的项目，使其必然失败
    const createTx = await factory.connect(project).createCampaign(
      ethers.parseEther("10"),
      1000,
      2000,
      "失败测试项目",
      "FAIL",
      { value: ethers.parseEther("0.02") }
    );
    await createTx.wait();
    const campaignAddress = await factory.allCampaigns(0);
    const Campaign = await ethers.getContractFactory("Campaign", deployer);
    const campaign = Campaign.attach(campaignAddress);

    const bobBalanceBefore = await ethers.provider.getBalance(bob.address);
    console.log("💰 退款前 Bob 的 ETH 余额:", ethers.formatEther(bobBalanceBefore));

    await campaign.connect(bob).pledge({ value: ethers.parseEther("1") });
    console.log("🏃 Bob 向必然失败的项目投入 1 ETH");

    await campaign.connect(project).finalize();
    console.log("🏁 众筹结算。成功状态:", await campaign.success());
    expect(await campaign.success()).to.equal(false);

    const refundTx = await campaign.connect(bob).refund();
    await refundTx.wait();
    console.log("🔄 众筹失败，Bob 已申请退款");

    const bobBalanceAfter = await ethers.provider.getBalance(bob.address);
    console.log("💰 退款后 Bob 的 ETH 余额:", ethers.formatEther(bobBalanceAfter));
    expect(bobBalanceAfter).to.be.gte(bobBalanceBefore - ethers.parseEther("0.01"));
  });
});