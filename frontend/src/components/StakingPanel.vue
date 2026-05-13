<template>
  <div class="staking-root">
    <div class="stats-grid">
      <div class="stat-card">
        <span class="stat-label">钱包 ETH</span>
        <strong class="stat-value">{{ balance }}</strong>
      </div>
      <div class="stat-card">
        <span class="stat-label">已质押</span>
        <strong class="stat-value">{{ staked }} ETH</strong>
      </div>
      <div class="stat-card">
        <span class="stat-label">可抵扣 R</span>
        <strong class="stat-value">{{ earned }}</strong>
      </div>
      <div class="stat-card">
        <span class="stat-label">金库 TVL</span>
        <strong class="stat-value">{{ vaultTotalETH }} ETH</strong>
      </div>
      <div class="stat-card">
        <span class="stat-label">金库总 R</span>
        <strong class="stat-value">{{ vaultTotalR }}</strong>
      </div>
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
          type="button"
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
          type="button"
          @click="handleUnstake"
          :disabled="!unstakeAmount || unstakeAmount <= 0 || isProcessing"
          class="unstake-btn"
        >
          {{ isProcessing ? '处理中...' : '赎回 ETH' }}
        </button>
      </div>
    </div>

    <div v-if="status" :class="['status-msg', { error: isError }]">
      {{ status }}
    </div>
  </div>
</template>

<script setup>
import { ref, inject, watch, onUnmounted } from 'vue';

const wallet = inject('wallet', null);

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

let refreshTimer = null;

function stopPoll() {
  if (refreshTimer) {
    clearInterval(refreshTimer);
    refreshTimer = null;
  }
}

async function refreshData() {
  if (!wallet?.account || !wallet?.sdk) return;
  const acc = wallet.account;
  const sdkVal = wallet.sdk;

  try {
    balance.value = await sdkVal.getWalletBalance(acc);
    staked.value = await sdkVal.getStakedAmount(acc);
    earned.value = await sdkVal.getEarned(acc);
    vaultTotalETH.value = await sdkVal.getVaultTotalETH();
    vaultTotalR.value = await sdkVal.getVaultTotalR();
    isError.value = false;
  } catch (err) {
    console.error('刷新失败', err);
    status.value = `❌ 数据刷新失败: ${err.message}`;
    isError.value = true;
  }
}

watch(
  () => (wallet ? [wallet.account, wallet.sdk] : [null, null]),
  ([acc, sdkVal]) => {
    stopPoll();
    if (!acc || !sdkVal) {
      balance.value = '0';
      staked.value = '0';
      earned.value = '0';
      vaultTotalETH.value = '0';
      vaultTotalR.value = '0';
      return;
    }
    refreshData();
    refreshTimer = setInterval(refreshData, 5000);
  },
  { immediate: true }
);

onUnmounted(() => {
  stopPoll();
});

async function handleStake() {
  if (!wallet?.account || !wallet?.sdk) return;

  isProcessing.value = true;
  status.value = '⏳ 请确认质押交易...';
  isError.value = false;

  try {
    await wallet.sdk.stake(wallet.account, stakeAmount.value.toString());
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
  if (!wallet?.account || !wallet?.sdk) return;

  isProcessing.value = true;
  status.value = '⏳ 请确认赎回交易...';
  isError.value = false;

  try {
    await wallet.sdk.unstake(wallet.account, unstakeAmount.value.toString());
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
</script>

<style scoped>
.staking-root {
  padding: 0;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(130px, 1fr));
  gap: 10px;
  margin-bottom: 18px;
}

.stat-card {
  background: var(--surface-soft, rgba(248, 250, 252, 0.96));
  border: 1px solid rgba(226, 232, 240, 0.95);
  border-radius: 12px;
  padding: 12px 12px;
}

.stat-label {
  display: block;
  font-size: 0.72rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: #64748b;
  margin-bottom: 6px;
}

.stat-value {
  font-size: 0.98rem;
  font-variant-numeric: tabular-nums;
  color: #0f172a;
}

.actions {
  margin-top: 4px;
}

.row {
  display: flex;
  align-items: flex-end;
  gap: 12px;
  margin-bottom: 14px;
}

.input-group {
  display: flex;
  flex-direction: column;
  gap: 8px;
  flex: 1;
}

.input-group label {
  font-size: 0.88rem;
  color: #334155;
  font-weight: 650;
}

.input-group input {
  padding: 11px 12px;
  border-radius: 12px;
  border: 1px solid rgba(148, 163, 184, 0.45);
  background: rgba(255, 255, 255, 0.95);
  outline: none;
  transition: box-shadow 140ms ease, border-color 140ms ease;
}

.input-group input:focus {
  border-color: rgba(59, 130, 246, 0.65);
  box-shadow: 0 0 0 4px rgba(59, 130, 246, 0.2);
}

.stake-btn,
.unstake-btn {
  padding: 12px 18px;
  border: none;
  border-radius: 12px;
  color: #fff;
  cursor: pointer;
  min-width: 118px;
  font-weight: 700;
  letter-spacing: 0.2px;
  box-shadow: 0 8px 18px rgba(2, 6, 23, 0.12);
  transition: transform 120ms ease, filter 120ms ease;
}

.stake-btn:hover:not(:disabled),
.unstake-btn:hover:not(:disabled) {
  transform: translateY(-1px);
  filter: brightness(1.02);
}

.stake-btn:disabled,
.unstake-btn:disabled {
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

.status-msg {
  margin-top: 14px;
  padding: 12px 14px;
  border-radius: 12px;
  background: rgba(239, 246, 255, 0.95);
  border: 1px solid rgba(59, 130, 246, 0.26);
  color: #0f172a;
  font-size: 0.92rem;
}

.status-msg.error {
  background: rgba(254, 242, 242, 0.96);
  border: 1px solid rgba(239, 68, 68, 0.26);
  color: #7f1d1d;
}

@media (max-width: 520px) {
  .row {
    flex-direction: column;
    align-items: stretch;
  }
  .stake-btn,
  .unstake-btn {
    width: 100%;
  }
}
</style>
