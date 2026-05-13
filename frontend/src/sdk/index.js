import { createPublicClient, createWalletClient, http, parseEther, formatEther, custom, defineChain } from 'viem';
import { STAKING_VAULT_ABI as STAKING_ABI, STAKING_ADDR, CROWDFUND_FACTORY_ABI, CROWDFUND_FACTORY_ADDR, CAMPAIGN_ABI } from './contract.js';

// 自定义 Hardhat 网络配置
const hardhat = defineChain({
  id: 31337,
  name: 'Hardhat',
  network: 'hardhat',
  nativeCurrency: {
    decimals: 18,
    name: 'Ether',
    symbol: 'ETH',
  },
  rpcUrls: {
    default: { http: ['http://127.0.0.1:8545'] },
    public: { http: ['http://127.0.0.1:8545'] },
  },
});

export const createStakingSDK = (windowProvider = null) => {
  const publicClient = createPublicClient({
    chain: hardhat, // 使用刚才定义的 hardhat
    transport: http("http://127.0.0.1:8545")
  });

  let walletClient = null;
  if (windowProvider) {
    walletClient = createWalletClient({
      chain: hardhat, // 统一使用 hardhat
      transport: custom(windowProvider)
    });
  }

  const weiToEther = (data) => (data === undefined ? '0' : formatEther(data));

  const readStaking = (functionName, args = []) =>
    publicClient.readContract({
      address: STAKING_ADDR,
      abi: STAKING_ABI,
      functionName,
      args,
    });

  const readFactory = (functionName, args = []) =>
    publicClient.readContract({
      address: CROWDFUND_FACTORY_ADDR,
      abi: CROWDFUND_FACTORY_ABI,
      functionName,
      args,
    });

  const readCampaign = (campaignAddress, functionName, args = []) =>
    publicClient.readContract({
      address: campaignAddress,
      abi: CAMPAIGN_ABI,
      functionName,
      args,
    });

  return {
    // --- 基础查询 ---
    async getVaultTotalETH() {
      return weiToEther(await readStaking('totalETH'));
    },

    async getVaultTotalR() {
      return weiToEther(await readStaking('totalR'));
    },

    async getWalletBalance(userAddress) {
      const data = await publicClient.getBalance({
        address: userAddress,
      });
      return weiToEther(data);
    },

    async getFactoryInfo() {
      const [globalVault, minDeposit] = await Promise.all([
        readFactory('globalVault'),
        readFactory('minDeposit'),
      ]);
      return {
        globalVault,
        minDeposit: weiToEther(minDeposit),
      };
    },

    async getFactoryCampaigns(maxCount = 20) {
      const total = Number(await readFactory('campaignCount'));
      const n = Math.min(maxCount, Number.isFinite(total) ? total : 0);
      const campaigns = [];
      for (let i = 0; i < n; i++) {
        campaigns.push(await readFactory('allCampaigns', [BigInt(i)]));
      }
      return campaigns;
    },

    async getEarned(userAddress) {
      return weiToEther(await readStaking('userR', [userAddress]));
    },

    async getStakedAmount(userAddress) {
      const data = await readStaking('users', [userAddress]);
      const amount = data?.amount ?? data?.[0];
      return weiToEther(amount);
    },

    async getCampaignInfo(campaignAddress) {
      const [creator, target, raised, totalContribution, maxDeductionRatio, deposit, finalized, success, raisedWithdrawn, depositWithdrawn, tokenAddress] = await Promise.all([
        readCampaign(campaignAddress, 'creator'),
        readCampaign(campaignAddress, 'target'),
        readCampaign(campaignAddress, 'raised'),
        readCampaign(campaignAddress, 'totalContribution'),
        readCampaign(campaignAddress, 'maxDeductionRatio'),
        readCampaign(campaignAddress, 'deposit'),
        readCampaign(campaignAddress, 'finalized'),
        readCampaign(campaignAddress, 'success'),
        readCampaign(campaignAddress, 'raisedWithdrawn'),
        readCampaign(campaignAddress, 'depositWithdrawn'),
        readCampaign(campaignAddress, 'token'),
      ]);
      return {
        creator,
        target: weiToEther(target),
        raised: weiToEther(raised),
        totalContribution: weiToEther(totalContribution),
        maxDeductionRatio: Number(maxDeductionRatio),
        deposit: weiToEther(deposit),
        finalized,
        success,
        raisedWithdrawn,
        depositWithdrawn,
        tokenAddress,
      };
    },

    async getCampaignUserInfo(campaignAddress, userAddress) {
      const [contribution, ethContributed] = await Promise.all([
        readCampaign(campaignAddress, 'contribution', [userAddress]),
        readCampaign(campaignAddress, 'ethContributed', [userAddress]),
      ]);
      return {
        contribution: weiToEther(contribution),
        ethContributed: weiToEther(ethContributed),
      };
    },

    async createCampaign(userAddress, target, totalToken, ratio, name, symbol, deposit) {
      if (!walletClient) throw new Error('钱包未连接');
      const args = [parseEther(target), BigInt(totalToken), BigInt(ratio), name, symbol];
      const value = parseEther(String(deposit || '0'));
      const gas = await publicClient.estimateContractGas({
        address: CROWDFUND_FACTORY_ADDR,
        abi: CROWDFUND_FACTORY_ABI,
        functionName: 'createCampaign',
        args,
        value,
        account: userAddress,
      });
      const hash = await walletClient.writeContract({
        address: CROWDFUND_FACTORY_ADDR,
        abi: CROWDFUND_FACTORY_ABI,
        functionName: 'createCampaign',
        args,
        account: userAddress,
        value,
        gas,
      });
      // 等待交易上链后再返回，避免前端立刻刷新读不到新 Campaign
      await publicClient.waitForTransactionReceipt({ hash });
      return hash;
    },

    async pledge(campaignAddress, userAddress, amount) {
      if (!walletClient) throw new Error('钱包未连接');
      const value = parseEther(String(amount || '0'));
      const gas = await publicClient.estimateContractGas({
        address: campaignAddress,
        abi: CAMPAIGN_ABI,
        functionName: 'pledge',
        value,
        account: userAddress,
      });
      return await walletClient.writeContract({
        address: campaignAddress,
        abi: CAMPAIGN_ABI,
        functionName: 'pledge',
        account: userAddress,
        value,
        gas,
      });
    },

    async finalizeCampaign(campaignAddress, userAddress) {
      if (!walletClient) throw new Error('钱包未连接');
      const gas = await publicClient.estimateContractGas({
        address: campaignAddress,
        abi: CAMPAIGN_ABI,
        functionName: 'finalize',
        account: userAddress,
      });
      return await walletClient.writeContract({
        address: campaignAddress,
        abi: CAMPAIGN_ABI,
        functionName: 'finalize',
        account: userAddress,
        gas,
      });
    },

    async claimCampaign(campaignAddress, userAddress) {
      if (!walletClient) throw new Error('钱包未连接');
      const gas = await publicClient.estimateContractGas({
        address: campaignAddress,
        abi: CAMPAIGN_ABI,
        functionName: 'claim',
        account: userAddress,
      });
      return await walletClient.writeContract({
        address: campaignAddress,
        abi: CAMPAIGN_ABI,
        functionName: 'claim',
        account: userAddress,
        gas,
      });
    },

    async refundCampaign(campaignAddress, userAddress) {
      if (!walletClient) throw new Error('钱包未连接');
      const gas = await publicClient.estimateContractGas({
        address: campaignAddress,
        abi: CAMPAIGN_ABI,
        functionName: 'refund',
        account: userAddress,
      });
      return await walletClient.writeContract({
        address: campaignAddress,
        abi: CAMPAIGN_ABI,
        functionName: 'refund',
        account: userAddress,
        gas,
      });
    },

    async withdrawRaised(campaignAddress, userAddress) {
      if (!walletClient) throw new Error('钱包未连接');
      const gas = await publicClient.estimateContractGas({
        address: campaignAddress,
        abi: CAMPAIGN_ABI,
        functionName: 'withdrawRaised',
        account: userAddress,
      });
      return await walletClient.writeContract({
        address: campaignAddress,
        abi: CAMPAIGN_ABI,
        functionName: 'withdrawRaised',
        account: userAddress,
        gas,
      });
    },

    async withdrawDeposit(campaignAddress, userAddress) {
      if (!walletClient) throw new Error('钱包未连接');
      const gas = await publicClient.estimateContractGas({
        address: campaignAddress,
        abi: CAMPAIGN_ABI,
        functionName: 'withdrawDeposit',
        account: userAddress,
      });
      return await walletClient.writeContract({
        address: campaignAddress,
        abi: CAMPAIGN_ABI,
        functionName: 'withdrawDeposit',
        account: userAddress,
        gas,
      });
    },

    async stake(userAddress, amount) {
      if (!walletClient) throw new Error('钱包未连接');
      const safeAmount = String(amount || '0');
      const value = parseEther(safeAmount);
      const gas = await publicClient.estimateContractGas({
        address: STAKING_ADDR,
        abi: STAKING_ABI,
        functionName: 'stake',
        value,
        account: userAddress,
      });
      return await walletClient.writeContract({
        address: STAKING_ADDR,
        abi: STAKING_ABI,
        functionName: 'stake',
        account: userAddress,
        value,
        gas,
      });
    },

    async unstake(userAddress, amount) {
      if (!walletClient) throw new Error('钱包未连接');
      const safeAmount = String(amount || '0');
      const args = [parseEther(safeAmount)];
      const gas = await publicClient.estimateContractGas({
        address: STAKING_ADDR,
        abi: STAKING_ABI,
        functionName: 'unstake',
        args,
        account: userAddress,
      });
      return await walletClient.writeContract({
        address: STAKING_ADDR,
        abi: STAKING_ABI,
        functionName: 'unstake',
        args,
        account: userAddress,
        gas,
      });
    },
  };
};