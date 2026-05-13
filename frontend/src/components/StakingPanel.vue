<template>
  <div class="staking-container">
    <h2>Staking Vault DApp</h2>

    <button v-if="!account" @click="connectWallet" class="connect-btn">连接钱包</button>

    <div v-else>
      <p class="account-info">当前账号: <code>{{ shortAddress }}</code></p>

      <div class="stats">
        <p>钱包 ETH 余额: <strong>{{ balance }} ETH</strong></p>
        <p>已质押: <strong>{{ staked }} ETH</strong></p>
        <p>可领取 R: <strong>{{ earned }} R</strong></p>
        <p>金库总质押: <strong>{{ vaultTotalETH }} ETH</strong></p>
        <p>金库总奖励: <strong>{{ vaultTotalR }} R</strong></p>
      </div>

      <div class="actions">
        <div class="row">
          <div class="input-group">
            <label>质押 ETH</label>
            <input
              v-model="stakeAmount"
              type="number"
              step="0.01"
              min="0"
              placeholder="输入 ETH"
            />
          </div>
          <button
            @click="handleStake"
            :disabled="!stakeAmount || stakeAmount <= 0 || isProcessing"
            class="stake-btn"
          >
            {{ isProcessing ? '处理中...' : '质押 ETH' }}
          </button>
        </div>

        <div class="row">
          <div class="input-group">
            <label>赎回 ETH</label>
            <input
              v-model="unstakeAmount"
              type="number"
              step="0.01"
              min="0"
              placeholder="输入 ETH"
            />
          </div>
          <button
            @click="handleUnstake"
            :disabled="!unstakeAmount || unstakeAmount <= 0 || isProcessing"
            class="unstake-btn"
          >
            {{ isProcessing ? '处理中...' : '赎回 ETH' }}
          </button>
        </div>
      </div>
    </div>

    <div v-if="status" :class="['status-msg', { error: isError }]">
      {{ status }}
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { createStakingSDK } from '../sdk/index.js';

const account = ref(null);
const balance = ref('0');
const staked = ref('0');
const earned = ref('0');
const vaultTotalETH = ref('0');
const vaultTotalR = ref('0');
const stakeAmount = ref('');
const unstakeAmount = ref('');
const status = ref('');
const isProcessing = ref(false);
const isError = ref(false);
const sdk = ref(null);
let refreshTimer = null;

const shortAddress = computed(() =>
  account.value ? `${account.value.slice(0, 6)}...${account.value.slice(-4)}` : ''
);

async function connectWallet() {
  if (!window.ethereum) {
    status.value = '请安装 MetaMask 或支持的以太坊钱包';
    isError.value = true;
    return;
  }

  const HARDHAT_CHAIN_ID = '0x7a69';

  try {
    const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });

    try {
      await window.ethereum.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: HARDHAT_CHAIN_ID }],
      });
    } catch (err) {
      if (err.code === 4902) {
        await window.ethereum.request({
          method: 'wallet_addEthereumChain',
          params: [{
            chainId: HARDHAT_CHAIN_ID,
            chainName: 'Hardhat Local',
            nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
            rpcUrls: ['http://127.0.0.1:8545'],
          }],
        });
      }
    }

    account.value = accounts[0];
    sdk.value = createStakingSDK(window.ethereum);
    await refreshData();
    status.value = '✅ 钱包已连接';
    isError.value = false;
  } catch (err) {
    status.value = `❌ 连接失败: ${err.message}`;
    isError.value = true;
  }
}

async function refreshData() {
  if (!account.value || !sdk.value) return;

  try {
    balance.value = await sdk.value.getWalletBalance(account.value);
    staked.value = await sdk.value.getStakedAmount(account.value);
    earned.value = await sdk.value.getEarned(account.value);
    vaultTotalETH.value = await sdk.value.getVaultTotalETH();
    vaultTotalR.value = await sdk.value.getVaultTotalR();
    isError.value = false;
  } catch (err) {
    console.error('刷新失败', err);
    status.value = `❌ 数据刷新失败: ${err.message}`;
    isError.value = true;
  }
}

async function handleStake() {
  if (!account.value || !sdk.value) return;

  isProcessing.value = true;
  status.value = '⏳ 请确认质押交易...';
  isError.value = false;

  try {
    await sdk.value.stake(account.value, stakeAmount.value.toString());
    stakeAmount.value = '';
    status.value = '✅ 质押成功';
    await refreshData();
  } catch (err) {
    console.error('质押失败', err);
    status.value = `❌ 质押失败: ${err.message}`;
    isError.value = true;
  } finally {
    isProcessing.value = false;
  }
}

async function handleUnstake() {
  if (!account.value || !sdk.value) return;

  isProcessing.value = true;
  status.value = '⏳ 请确认赎回交易...';
  isError.value = false;

  try {
    await sdk.value.unstake(account.value, unstakeAmount.value.toString());
    unstakeAmount.value = '';
    status.value = '✅ 赎回成功';
    await refreshData();
  } catch (err) {
    console.error('赎回失败', err);
    status.value = `❌ 赎回失败: ${err.message}`;
    isError.value = true;
  } finally {
    isProcessing.value = false;
  }
}

onMounted(() => {
  const handleAccountsChanged = (accounts) => {
    const next = accounts?.[0] ?? null;
    account.value = next;
    if (!next) {
      balance.value = '0';
      staked.value = '0';
      earned.value = '0';
      status.value = '钱包已断开连接';
      isError.value = false;
      return;
    }
    sdk.value = createStakingSDK(window.ethereum);
    refreshData();
  };

  const handleChainChanged = () => {
    sdk.value = createStakingSDK(window.ethereum);
    if (account.value) refreshData();
  };

  if (window.ethereum?.on) {
    window.ethereum.on('accountsChanged', handleAccountsChanged);
    window.ethereum.on('chainChanged', handleChainChanged);
  }

  refreshTimer = setInterval(() => {
    if (account.value) refreshData();
  }, 5000);

  onUnmounted(() => {
    if (refreshTimer) clearInterval(refreshTimer);
    refreshTimer = null;
    if (window.ethereum?.removeListener) {
      window.ethereum.removeListener('accountsChanged', handleAccountsChanged);
      window.ethereum.removeListener('chainChanged', handleChainChanged);
    }
  });
});
</script>

<style scoped>
.staking-container {
  padding: 26px 22px;
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.92);
  border: 1px solid rgba(226, 232, 240, 0.8);
  box-shadow: 0 18px 45px rgba(2, 6, 23, 0.28);
  backdrop-filter: blur(10px);
}

.staking-container h2 {
  margin: 2px 0 18px;
  font-size: 1.25rem;
  letter-spacing: 0.2px;
}

.account-info {
  margin: 8px 0 14px;
  color: #334155;
}

.account-info code {
  padding: 2px 8px;
  border-radius: 999px;
  background: rgba(148, 163, 184, 0.18);
  border: 1px solid rgba(148, 163, 184, 0.28);
}

.stats {
  background: rgba(248, 250, 252, 0.92);
  padding: 16px 16px;
  border-radius: 14px;
  margin-bottom: 18px;
  line-height: 1.85;
  border: 1px solid rgba(226, 232, 240, 0.9);
}

.stats p {
  margin: 6px 0;
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
}

.stats strong {
  font-variant-numeric: tabular-nums;
  color: #0f172a;
}

.input-group {
  display: flex;
  flex-direction: column;
  gap: 8px;
  flex: 1;
}

.input-group label {
  font-size: 0.9rem;
  color: #334155;
  font-weight: 650;
}

.input-group input {
  padding: 12px 12px;
  border-radius: 12px;
  border: 1px solid rgba(148, 163, 184, 0.45);
  background: rgba(255, 255, 255, 0.9);
  outline: none;
  transition: box-shadow 140ms ease, border-color 140ms ease, transform 140ms ease;
}

.input-group input:focus {
  border-color: rgba(59, 130, 246, 0.65);
  box-shadow: 0 0 0 4px rgba(59, 130, 246, 0.22);
}

.row {
  display: flex;
  align-items: flex-end;
  gap: 12px;
  margin-bottom: 16px;
}

button {
  padding: 12px 18px;
  border: none;
  border-radius: 10px;
  color: #fff;
  cursor: pointer;
  min-width: 120px;
  font-weight: 700;
  letter-spacing: 0.2px;
  box-shadow: 0 10px 20px rgba(2, 6, 23, 0.14);
  transition: transform 120ms ease, filter 120ms ease, box-shadow 120ms ease;
}

button:hover:not(:disabled) {
  transform: translateY(-1px);
  filter: brightness(1.02);
  box-shadow: 0 14px 28px rgba(2, 6, 23, 0.18);
}

button:active:not(:disabled) {
  transform: translateY(0px);
}

button:disabled {
  background: rgba(148, 163, 184, 0.9);
  cursor: not-allowed;
  box-shadow: none;
}

.stake-btn {
  background: linear-gradient(180deg, #2563eb, #1d4ed8);
}

.unstake-btn {
  background: linear-gradient(180deg, #f59e0b, #ea580c);
}

.connect-btn {
  width: 100%;
  background: linear-gradient(180deg, #16a34a, #15803d);
  border-radius: 12px;
}

.status-msg {
  margin-top: 20px;
  padding: 14px 14px;
  border-radius: 14px;
  background: rgba(239, 246, 255, 0.92);
  border: 1px solid rgba(59, 130, 246, 0.26);
  color: #0f172a;
  box-shadow: 0 10px 24px rgba(2, 6, 23, 0.12);
}

.status-msg.error {
  background: rgba(254, 242, 242, 0.95);
  border: 1px solid rgba(239, 68, 68, 0.26);
  color: #7f1d1d;
}

@media (max-width: 520px) {
  .staking-container {
    padding: 20px 16px;
    border-radius: 16px;
  }
  .row {
    flex-direction: column;
    align-items: stretch;
  }
  button {
    width: 100%;
  }
}
</style>