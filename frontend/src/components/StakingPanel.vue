<template>
  <div class="staking-root">
    <!-- 主要统计卡片 -->
    <div class="primary-stats">
      <div class="primary-stat-card stake-card">
        <div class="stat-icon">🔒</div>
        <div class="stat-content">
          <span class="stat-label">已质押 ETH</span>
          <strong class="stat-value highlight">{{ staked }}</strong>
        </div>
      </div>
      <div class="primary-stat-card earn-card">
        <div class="stat-icon">💎</div>
        <div class="stat-content">
          <span class="stat-label">可抵扣 R</span>
          <strong class="stat-value highlight">{{ earned }}</strong>
        </div>
      </div>
    </div>

    <!-- 抵扣率进度条 -->
    <div class="ratio-bar-wrap">
      <div class="ratio-header">
        <span class="ratio-label">抵扣比率</span>
        <span class="ratio-value">{{ earned && staked ? (parseFloat(staked) > 0 ? (parseFloat(earned) / parseFloat(staked) * 100).toFixed(1) : '0.0') : '0.0' }}%</span>
      </div>
      <div class="ratio-bar">
        <div class="ratio-fill" :style="{ width: Math.min(parseFloat(earned) && parseFloat(staked) ? (parseFloat(earned) / parseFloat(staked) * 100) : 0, 100) + '%' }"></div>
      </div>
      <p class="ratio-hint">质押 ETH 自动累积 R，众筹认购时可抵扣付款</p>
    </div>

    <!-- 操作区域 -->
    <div class="actions">
      <div class="action-box stake-box">
        <div class="action-header">
          <span class="action-icon">⬆️</span>
          <span class="action-title">质押</span>
        </div>
        <div class="input-wrap">
          <input
            v-model="stakeAmount"
            type="number"
            step="0.01"
            min="0"
            placeholder="输入 ETH 数量"
          />
          <button
            type="button"
            @click="handleStake"
            :disabled="!stakeAmount || stakeAmount <= 0 || isProcessing"
            class="stake-btn"
          >
            {{ isProcessing ? '处理中...' : '确认质押' }}
          </button>
        </div>
      </div>

      <div class="action-box unstake-box">
        <div class="action-header">
          <span class="action-icon">⬇️</span>
          <span class="action-title">赎回</span>
        </div>
        <div class="input-wrap">
          <input
            v-model="unstakeAmount"
            type="number"
            step="0.01"
            min="0"
            placeholder="输入 ETH 数量"
          />
          <button
            type="button"
            @click="handleUnstake"
            :disabled="!unstakeAmount || unstakeAmount <= 0 || isProcessing"
            class="unstake-btn"
          >
            {{ isProcessing ? '处理中...' : '确认赎回' }}
          </button>
        </div>
      </div>
    </div>

    <!-- 次要统计 -->
    <div class="secondary-stats">
      <div class="sec-stat">
        <span class="sec-label">💰 钱包余额</span>
        <strong class="sec-value">{{ balance }} ETH</strong>
      </div>
      <div class="sec-stat">
        <span class="sec-label">🏦 金库 TVL</span>
        <strong class="sec-value">{{ vaultTotalETH }} ETH</strong>
      </div>
      <div class="sec-stat">
        <span class="sec-label">📊 金库总 R</span>
        <strong class="sec-value">{{ vaultTotalR }}</strong>
      </div>
    </div>

    <!-- 说明卡片 -->
    <div class="info-card">
      <div class="info-title">💡 使用说明</div>
      <ul class="info-list">
        <li>质押 ETH 到金库，自动累积 R 奖励</li>
        <li>R 可在众筹认购时抵扣实际支付金额</li>
        <li>赎回将取回对应数量的 ETH</li>
        <li>最小质押单位 0.01 ETH</li>
      </ul>
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
  display: flex;
  flex-direction: column;
  gap: 16px;
}

/* 主要统计 */
.primary-stats {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

.primary-stat-card {
  border-radius: 14px;
  padding: 16px;
  display: flex;
  align-items: center;
  gap: 12px;
  border: 1px solid;
}

.stake-card {
  background: linear-gradient(135deg, rgba(37, 99, 235, 0.08), rgba(29, 78, 216, 0.04));
  border-color: rgba(37, 99, 235, 0.18);
}

.earn-card {
  background: linear-gradient(135deg, rgba(22, 163, 74, 0.08), rgba(21, 128, 61, 0.04));
  border-color: rgba(22, 163, 74, 0.18);
}

.stat-icon {
  font-size: 1.5rem;
  width: 42px;
  height: 42px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.7);
  flex-shrink: 0;
}

.stake-card .stat-icon {
  background: rgba(37, 99, 235, 0.12);
}

.earn-card .stat-icon {
  background: rgba(22, 163, 74, 0.12);
}

.stat-content {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}

.stat-label {
  font-size: 0.72rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: #64748b;
}

.stat-value {
  font-size: 1.15rem;
  font-variant-numeric: tabular-nums;
  color: #0f172a;
}

.stat-value.highlight {
  font-weight: 800;
  letter-spacing: -0.01em;
}

/* 抵扣率进度条 */
.ratio-bar-wrap {
  background: rgba(248, 250, 252, 0.96);
  border: 1px solid rgba(226, 232, 240, 0.95);
  border-radius: 14px;
  padding: 14px 16px;
}

.ratio-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
}

.ratio-label {
  font-size: 0.82rem;
  font-weight: 700;
  color: #334155;
}

.ratio-value {
  font-size: 0.88rem;
  font-weight: 800;
  color: #16a34a;
  font-variant-numeric: tabular-nums;
}

.ratio-bar {
  height: 8px;
  border-radius: 999px;
  background: rgba(226, 232, 240, 0.8);
  overflow: hidden;
}

.ratio-fill {
  height: 100%;
  border-radius: 999px;
  background: linear-gradient(90deg, #22c55e, #16a34a);
  transition: width 0.5s ease;
  min-width: 0;
}

.ratio-hint {
  margin: 8px 0 0;
  font-size: 0.76rem;
  color: #94a3b8;
  line-height: 1.4;
}

/* 操作区域 */
.actions {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.action-box {
  background: rgba(248, 250, 252, 0.96);
  border: 1px solid rgba(226, 232, 240, 0.95);
  border-radius: 14px;
  padding: 14px 16px;
}

.action-header {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-bottom: 10px;
}

.action-icon {
  font-size: 0.95rem;
}

.action-title {
  font-size: 0.88rem;
  font-weight: 750;
  color: #0f172a;
}

.input-wrap {
  display: flex;
  gap: 10px;
}

.input-wrap input {
  flex: 1;
  min-width: 0;
  padding: 11px 12px;
  border-radius: 12px;
  border: 1px solid rgba(148, 163, 184, 0.45);
  background: rgba(255, 255, 255, 0.95);
  outline: none;
  font-size: 0.9rem;
  transition: box-shadow 140ms ease, border-color 140ms ease;
}

.input-wrap input:focus {
  border-color: rgba(59, 130, 246, 0.65);
  box-shadow: 0 0 0 4px rgba(59, 130, 246, 0.15);
}

.stake-btn,
.unstake-btn {
  padding: 11px 18px;
  border: none;
  border-radius: 12px;
  color: #fff;
  cursor: pointer;
  min-width: 100px;
  font-weight: 700;
  font-size: 0.88rem;
  white-space: nowrap;
  box-shadow: 0 6px 16px rgba(2, 6, 23, 0.1);
  transition: transform 120ms ease, filter 120ms ease;
}

.stake-btn:hover:not(:disabled),
.unstake-btn:hover:not(:disabled) {
  transform: translateY(-1px);
  filter: brightness(1.02);
}

.stake-btn:disabled,
.unstake-btn:disabled {
  background: rgba(148, 163, 184, 0.9) !important;
  cursor: not-allowed;
  box-shadow: none;
}

.stake-btn {
  background: linear-gradient(180deg, #2563eb, #1d4ed8);
}

.unstake-btn {
  background: linear-gradient(180deg, #f59e0b, #ea580c);
}

/* 次要统计 */
.secondary-stats {
  display: flex;
  flex-direction: column;
  gap: 0;
  background: rgba(248, 250, 252, 0.96);
  border: 1px solid rgba(226, 232, 240, 0.95);
  border-radius: 14px;
  overflow: hidden;
}

.sec-stat {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 11px 16px;
  border-bottom: 1px solid rgba(226, 232, 240, 0.7);
}

.sec-stat:last-child {
  border-bottom: none;
}

.sec-label {
  font-size: 0.82rem;
  color: #64748b;
  font-weight: 600;
}

.sec-value {
  font-size: 0.9rem;
  color: #0f172a;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}

/* 说明卡片 */
.info-card {
  background: linear-gradient(135deg, rgba(99, 102, 241, 0.06), rgba(139, 92, 246, 0.04));
  border: 1px solid rgba(99, 102, 241, 0.15);
  border-radius: 14px;
  padding: 14px 16px;
}

.info-title {
  font-size: 0.85rem;
  font-weight: 750;
  color: #4338ca;
  margin-bottom: 8px;
}

.info-list {
  margin: 0;
  padding-left: 18px;
  list-style: disc;
}

.info-list li {
  font-size: 0.78rem;
  color: #64748b;
  line-height: 1.6;
}

/* 状态消息 */
.status-msg {
  padding: 12px 14px;
  border-radius: 12px;
  background: rgba(239, 246, 255, 0.95);
  border: 1px solid rgba(59, 130, 246, 0.26);
  color: #0f172a;
  font-size: 0.88rem;
}

.status-msg.error {
  background: rgba(254, 242, 242, 0.96);
  border: 1px solid rgba(239, 68, 68, 0.26);
  color: #7f1d1d;
}

@media (max-width: 520px) {
  .primary-stats {
    grid-template-columns: 1fr;
  }

  .input-wrap {
    flex-direction: column;
  }

  .stake-btn,
  .unstake-btn {
    width: 100%;
  }
}
</style>
