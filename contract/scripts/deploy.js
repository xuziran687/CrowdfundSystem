const hre = require("hardhat");

async function main() {
    const [deployer] = await hre.ethers.getSigners();

    console.log("\n>>> 开始部署全平台合约 <<<");
    console.log(`部署者账户: ${deployer.address}\n`);
    // 1. 部署数学库 MathLogic
    console.log("[1/4] 正在部署 MathLogic 库...");
    const MathLogic = await hre.ethers.getContractFactory("MathLogic");
    const mathLogic = await MathLogic.deploy();
    await mathLogic.waitForDeployment();// 等待部署完成
    const mathLogicAddr = await mathLogic.getAddress();
    console.log(`MathLogic 部署成功: ${mathLogicAddr}`);
    // 2. 部署 StakingVault (金库)
    console.log("\n[2/4] 正在部署 StakingVault...");
    const StakingVault = await hre.ethers.getContractFactory("StakingVault");
    const vault = await StakingVault.deploy();
    await vault.waitForDeployment();// 等待部署完成
    const vaultAddr = await vault.getAddress();
    console.log(`StakingVault 部署成功: ${vaultAddr}`);
    // 3. 部署 CrowdfundFactory (工厂)
    // 注意：部署时需要传入 Vault 的地址和最小保证金
    console.log("[3/4] 正在部署 CrowdfundFactory...");
    const Factory = await hre.ethers.getContractFactory("CrowdfundFactory");
    const minDeposit = hre.ethers.parseEther("0.01");
    const factory = await Factory.deploy(vaultAddr, minDeposit);
    await factory.waitForDeployment();// 等待部署完成
    const factoryAddr = await factory.getAddress();
    console.log(`CrowdfundFactory 部署成功: ${factoryAddr}`);
    // 4. 核心步骤：权限授权 (Linking)
    // 只有工厂有权在金库中注册新的 Campaign
    console.log("\n[4/4] 正在执行合约关联与权限初始化...");
    // 假设你的 Vault 有个 setFactory 或者是 constructor 里定死的
    // 根据我们的代码，Vault 的 factory 是部署者，所以需要验证
    console.log("🔗 关联确认：金库中的工厂地址配置中...");
    // 如果你在 Vault 中需要显式设置授权
    await vault.setFactory(factoryAddr);

    console.log("\n===============================================");
    console.log("所有合约部署完成！");
    console.log(`平台金库 (Vault):    ${vaultAddr}`);
    console.log(`项目工厂 (Factory):  ${factoryAddr}`);
    console.log("===============================================");

    // 5. 保存地址到本地文件，并同步前端地址配置
    const fs = require("fs");
    const path = require("path");
    const addresses = {
        MathLogic: mathLogicAddr,
        StakingVault: vaultAddr,
        CrowdfundFactory: factoryAddr
    };

    fs.writeFileSync("contract-addresses.json", JSON.stringify(addresses, null, 2));
    const frontendAddressesPath = path.resolve(__dirname, '..', '..', 'frontend', 'src', 'sdk', 'addresses.json');// 前端地址文件路径
    fs.writeFileSync(frontendAddressesPath, JSON.stringify(addresses, null, 2));

    console.log("合约地址已保存至 contract-addresses.json");
    console.log(`前端地址已保存至 ${frontendAddressesPath}`);
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});