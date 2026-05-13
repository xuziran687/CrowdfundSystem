<template>
  <div class="crowd-root">
    <!-- 工厂信息标签 -->
    <div class="factory-tags">
      <div class="ftag">
        <span class="ftag-label">工厂</span>
        <code class="ftag-value">{{ factoryInfo.address }}</code>
      </div>
      <div class="ftag">
        <span class="ftag-label">金库</span>
        <code class="ftag-value">{{ factoryInfo.globalVault }}</code>
      </div>
      <div class="ftag ftag-highlight">
        <span class="ftag-label">最小保证金</span>
        <strong class="ftag-value">{{ factoryInfo.minDeposit }} ETH</strong>
      </div>
    </div>

    <div class="crowd-workspace">
      <aside class="crowd-sidebar">
        <section class="box create-box">
          <div class="box-header">
            <span class="box-icon">🚀</span>
            <h3>发起新 Campaign</h3>
          </div>
          <div class="field-grid">
            <div class="field-row">
              <label>目标 ETH</label>
              <input v-model="createTarget" type="number" step="0.01" min="0" placeholder="目标 ETH" />
            </div>
            <div class="field-row">
              <label>发行总量</label>
              <input v-model="createTotalToken" type="number" step="1" min="0" placeholder="总代币数量" />
            </div>
            <div class="field-row">
              <label>抵扣比例 (BPS)</label>
              <input v-model="createRatio" type="number" step="1" min="0" placeholder="如 3000 = 30%" />
            </div>
            <div class="field-row">
              <label>项目名</label>
              <input v-model="createName" type="text" placeholder="项目名称" />
            </div>
            <div class="field-row">
              <label>符号</label>
              <input v-model="createSymbol" type="text" placeholder="代币符号" />
            </div>
            <div class="field-row">
              <label>保证金 ETH</label>
              <input v-model="createDeposit" type="number" step="0.01" min="0" placeholder="保证金 ETH" />
            </div>
          </div>
          <button type="button" @click="handleCreateCampaign" :disabled="isProcessing || !canCreate" class="action-btn create-btn">
            <span class="btn-icon">✨</span> 创建 Campaign
          </button>
        </section>

        <section class="box list-box">
          <div class="box-header">
            <span class="box-icon">📋</span>
            <h3>已发布 Campaign</h3>
            <span class="count-badge" v-if="campaigns.length > 0">{{ campaigns.length }}</span>
          </div>
          <div v-if="campaigns.length === 0" class="empty">暂无 Campaign，先创建一个。</div>
          <ul v-else class="campaign-list">
            <li
              v-for="address in campaigns"
              :key="address"
              :class="{ selected: selectedCampaign === address }"
              @click="selectCampaign(address)"
            >
              <span class="campaign-dot"></span>
              <span class="campaign-addr">{{ address }}</span>
            </li>
          </ul>
        </section>
      </aside>

      <div class="crowd-main">
        <section v-if="selectedCampaignInfo" class="box campaign-detail">
          <div class="detail-header">
            <h3>Campaign 详情</h3>
            <span :class="['status-badge', selectedCampaignInfo.finalized ? (selectedCampaignInfo.success ? 'badge-success' : 'badge-fail') : 'badge-active']">
              {{ selectedCampaignInfo.finalized ? (selectedCampaignInfo.success ? '✅ 成功' : '❌ 失败') : '🔄 进行中' }}
            </span>
          </div>

          <!-- 募集进度 -->
          <div class="progress-section">
            <div class="progress-header">
              <span class="progress-label">募集进度</span>
              <span class="progress-value">
                {{ selectedCampaignInfo.raised }} / {{ selectedCampaignInfo.target }} ETH
              </span>
            </div>
            <div class="progress-bar">
              <div class="progress-fill" :style="{ width: Math.min(parseFloat(selectedCampaignInfo.raised) && parseFloat(selectedCampaignInfo.target) ? (parseFloat(selectedCampaignInfo.raised) / parseFloat(selectedCampaignInfo.target) * 100) : 0, 100) + '%' }"></div>
            </div>
            <div class="progress-meta">
              <span>名义总额: {{ selectedCampaignInfo.totalContribution }} ETH</span>
              <span>抵扣上限: {{ selectedCampaignInfo.maxDeductionRatio }} BPS</span>
            </div>
          </div>

          <!-- 详情信息网格 -->
          <div class="detail-grid">
            <div class="detail-item">
              <span class="di-label">合约地址</span>
              <code class="di-value">{{ selectedCampaign }}</code>
            </div>
            <div class="detail-item">
              <span class="di-label">创建者</span>
              <code class="di-value">{{ selectedCampaignInfo.creator }}</code>
            </div>
            <div class="detail-item">
              <span class="di-label">保证金</span>
              <strong class="di-value">{{ selectedCampaignInfo.deposit }} ETH</strong>
            </div>
            <div class="detail-item">
              <span class="di-label">代币合约</span>
              <code class="di-value">{{ selectedCampaignInfo.tokenAddress }}</code>
            </div>
          </div>

          <!-- 我的参与 -->
          <div class="user-section">
            <h4>🎯 我的参与</h4>
            <div class="user-stats">
              <div class="us-item">
                <span class="us-label">名义贡献</span>
                <strong class="us-value">{{ selectedUserInfo.contribution }} ETH</strong>
              </div>
              <div class="us-item">
                <span class="us-label">实际支付</span>
                <strong class="us-value">{{ selectedUserInfo.ethContributed }} ETH</strong>
              </div>
            </div>
          </div>

          <!-- 认购输入 -->
          <div class="pledge-section">
            <div class="pledge-input">
              <label>认购金额</label>
              <div class="pledge-row">
                <input v-model="pledgeAmount" type="number" step="0.01" min="0" placeholder="输入 ETH" />
                <button type="button" @click="handlePledge" :disabled="isProcessing || !pledgeAmount" class="action-btn pledge-btn">认购</button>
              </div>
            </div>
          </div>

          <!-- 操作按钮 -->
          <div class="actions-area">
            <div class="actions-group">
              <h4>参与者操作</h4>
              <div class="actions-row">
                <button type="button" @click="handleClaim" :disabled="isProcessing || !selectedCampaignInfo.finalized || !selectedCampaignInfo.success" class="action-btn claim-btn">
                  🪙 领取代币
                </button>
                <button type="button" @click="handleRefund" :disabled="isProcessing || !selectedCampaignInfo.finalized || selectedCampaignInfo.success" class="action-btn warn-btn">
                  💰 退款
                </button>
              </div>
            </div>
            <div class="actions-group" v-if="selectedCampaignInfo.creator.toLowerCase() === wallet?.account?.toLowerCase()">
              <h4>创建者操作</h4>
              <div class="actions-row">
                <button type="button" @click="handleFinalize" :disabled="isProcessing || !canFinalize" class="action-btn primary-btn">
                  ⏹ 结束众筹
                </button>
                <button type="button" @click="handleWithdrawRaised" :disabled="isProcessing || !canWithdrawRaised" class="action-btn withdraw-btn">
                  💵 提取募集款
                </button>
                <button type="button" @click="handleWithdrawDeposit" :disabled="isProcessing || !canWithdrawDeposit" class="action-btn deposit-btn">
                  🔐 提取保证金
                </button>
              </div>
            </div>
          </div>

          <!-- 提取状态 -->
          <div class="withdraw-status" v-if="selectedCampaignInfo.finalized">
            <div class="ws-item" :class="{ done: selectedCampaignInfo.raisedWithdrawn }">
              {{ selectedCampaignInfo.raisedWithdrawn ? '✅' : '⏳' }} 募集款{{ selectedCampaignInfo.raisedWithdrawn ? '已提取' : '未提取' }}
            </div>
            <div class="ws-item" :class="{ done: selectedCampaignInfo.depositWithdrawn }">
              {{ selectedCampaignInfo.depositWithdrawn ? '✅' : '⏳' }} 保证金{{ selectedCampaignInfo.depositWithdrawn ? '已提取' : '未提取' }}
            </div>
          </div>
        </section>
        <div v-else class="empty-detail box">
          <div class="empty-icon">👈</div>
          <p>在左侧列表中选择一个 Campaign 查看详情与操作</p>
        </div>
      </div>
    </div>

    <div v-if="status" :class="['status-msg', { error: isError }]">
      {{ status }}
    </div>
  </div>
</template>

<script setup>
import { ref, computed, inject, watch, onUnmounted } from 'vue';
import { CROWDFUND_FACTORY_ADDR } from '../sdk/contract.js';

const wallet = inject('wallet', null);

const status = ref('');
const isProcessing = ref(false);
const isError = ref(false);

const factoryInfo = ref({ address: '', globalVault: '', minDeposit: '0' });
const campaigns = ref([]);
const selectedCampaign = ref('');
const selectedCampaignInfo = ref(null);
const selectedUserInfo = ref({ contribution: '0', ethContributed: '0' });

const createTarget = ref('');
const createTotalToken = ref('');
const createRatio = ref('');
const createName = ref('');
const createSymbol = ref('');
const createDeposit = ref('0');
const pledgeAmount = ref('');

let campaignsPollTimer = null;

function stopCampaignPoll() {
  if (campaignsPollTimer) {
    clearInterval(campaignsPollTimer);
    campaignsPollTimer = null;
  }
}

const canCreate = computed(() => {
  return createTarget.value > 0 && createTotalToken.value > 0 && createRatio.value > 0 && createName.value && createSymbol.value && createDeposit.value > 0;
});

const canFinalize = computed(() => {
  const acc = wallet?.account;
  return selectedCampaignInfo.value && acc && selectedCampaignInfo.value.creator.toLowerCase() === acc.toLowerCase() && !selectedCampaignInfo.value.finalized;
});

const canWithdrawRaised = computed(() => {
  const acc = wallet?.account;
  return selectedCampaignInfo.value && acc && selectedCampaignInfo.value.creator.toLowerCase() === acc.toLowerCase() && selectedCampaignInfo.value.finalized && selectedCampaignInfo.value.success && !selectedCampaignInfo.value.raisedWithdrawn;
});

const canWithdrawDeposit = computed(() => {
  const acc = wallet?.account;
  return selectedCampaignInfo.value && acc && selectedCampaignInfo.value.creator.toLowerCase() === acc.toLowerCase() && selectedCampaignInfo.value.finalized && !selectedCampaignInfo.value.depositWithdrawn;
});

watch(
  () => (wallet ? [wallet.account, wallet.sdk] : [null, null]),
  ([acc, sdkVal]) => {
    stopCampaignPoll();
    if (!acc || !sdkVal) {
      campaigns.value = [];
      selectedCampaign.value = '';
      selectedCampaignInfo.value = null;
      selectedUserInfo.value = { contribution: '0', ethContributed: '0' };
      return;
    }
    factoryInfo.value.address = factoryInfo.value.address || CROWDFUND_FACTORY_ADDR;
    refreshFactory();
    refreshCampaigns();
    campaignsPollTimer = setInterval(() => {
      if (wallet?.sdk && wallet?.account) refreshCampaigns();
    }, 5000);
  },
  { immediate: true }
);

onUnmounted(() => {
  stopCampaignPoll();
});

async function refreshFactory() {
  if (!wallet?.sdk) return;
  try {
    const info = await wallet.sdk.getFactoryInfo();
    factoryInfo.value = {
      address: factoryInfo.value.address || '',
      globalVault: info.globalVault,
      minDeposit: info.minDeposit,
    };
  } catch (err) {
    console.error('刷新工厂失败', err);
  }
}

async function refreshCampaigns() {
  if (!wallet?.sdk) return;
  try {
    campaigns.value = await wallet.sdk.getFactoryCampaigns(20);
  } catch (err) {
    console.error('获取 Campaign 列表失败', err);
  }
}

async function selectCampaign(address) {
  if (!wallet?.sdk || !address || !wallet?.account) return;
  selectedCampaign.value = address;
  try {
    selectedCampaignInfo.value = await wallet.sdk.getCampaignInfo(address);
    selectedUserInfo.value = await wallet.sdk.getCampaignUserInfo(address, wallet.account);
  } catch (err) {
    console.error('加载 Campaign 详情失败', err);
    status.value = `❌ 加载 Campaign 失败: ${err.message}`;
    isError.value = true;
  }
}

async function handleCreateCampaign() {
  if (!wallet?.sdk || !wallet?.account) return;
  isProcessing.value = true;
  status.value = '⏳ 正在创建 Campaign...';
  isError.value = false;

  try {
    const before = new Set(campaigns.value);
    await wallet.sdk.createCampaign(
      wallet.account,
      String(createTarget.value ?? '0'),
      String(createTotalToken.value ?? '0'),
      String(createRatio.value ?? '0'),
      createName.value,
      createSymbol.value,
      String(createDeposit.value ?? '0')
    );
    status.value = '✅ Campaign 创建成功';
    createTarget.value = '';
    createTotalToken.value = '';
    createRatio.value = '';
    createName.value = '';
    createSymbol.value = '';
    createDeposit.value = '0';
    await refreshCampaigns();
    const created = campaigns.value.find((addr) => !before.has(addr));
    if (created) {
      await selectCampaign(created);
    }
  } catch (err) {
    console.error('创建失败', err);
    status.value = `❌ 创建失败: ${err.message}`;
    isError.value = true;
  } finally {
    isProcessing.value = false;
  }
}

async function handlePledge() {
  if (!wallet?.sdk || !selectedCampaign.value || !wallet?.account) return;
  isProcessing.value = true;
  status.value = '⏳ 正在认购...';
  isError.value = false;

  try {
    await wallet.sdk.pledge(selectedCampaign.value, wallet.account, String(pledgeAmount.value ?? '0'));
    status.value = '✅ 认购成功';
    pledgeAmount.value = '';
    await selectCampaign(selectedCampaign.value);
    await refreshCampaigns();
  } catch (err) {
    console.error('认购失败', err);
    status.value = `❌ 认购失败: ${err.message}`;
    isError.value = true;
  } finally {
    isProcessing.value = false;
  }
}

async function handleFinalize() {
  if (!wallet?.sdk || !selectedCampaign.value || !wallet?.account) return;
  isProcessing.value = true;
  status.value = '⏳ 正在终结 Campaign...';
  isError.value = false;

  try {
    await selectCampaign(selectedCampaign.value);
    if (!selectedCampaignInfo.value) {
      throw new Error('无法获取选中 Campaign 详情');
    }
    if (selectedCampaignInfo.value.creator.toLowerCase() !== wallet.account.toLowerCase()) {
      throw new Error('当前连接账号不是该 Campaign 的创建者');
    }

    await wallet.sdk.finalizeCampaign(selectedCampaign.value, wallet.account);
    status.value = '✅ Campaign 终结成功';
    await selectCampaign(selectedCampaign.value);
  } catch (err) {
    console.error('终结失败', err);
    status.value = `❌ 终结失败: ${err.message}`;
    isError.value = true;
  } finally {
    isProcessing.value = false;
  }
}

async function handleClaim() {
  if (!wallet?.sdk || !selectedCampaign.value || !wallet?.account) return;
  isProcessing.value = true;
  status.value = '⏳ 正在领取项目代币...';
  isError.value = false;

  try {
    await wallet.sdk.claimCampaign(selectedCampaign.value, wallet.account);
    status.value = '✅ 领取成功，正在自动添加代币到 MetaMask...';
    
    if (selectedCampaignInfo.value?.tokenAddress) {
      const tokenSymbol = selectedCampaignInfo.value.symbol || 'TOKEN';
      const tokenDecimals = selectedCampaignInfo.value.decimals || 18;
      try {
        const success = await wallet.sdk.addTokenToWallet(
          selectedCampaignInfo.value.tokenAddress,
          tokenSymbol,
          tokenDecimals
        );
        
        if (success) {
          status.value = `✅ 领取成功，代币已成功添加到 MetaMask (小数位数: ${tokenDecimals})`;
        } else {
          status.value = '⚠️ 领取成功，但自动添加代币失败，请手动添加到 MetaMask';
          isError.value = true;
        }
      } catch (tokenErr) {
        console.error('添加代币到 MetaMask 失败:', tokenErr);
        status.value = '⚠️ 领取成功，但添加代币时出错，请手动添加到 MetaMask';
        isError.value = true;
      }
    } else {
      status.value = '⚠️ 领取成功，但无法获取代币地址，请手动添加到 MetaMask';
      isError.value = true;
    }
    
    await selectCampaign(selectedCampaign.value);
  } catch (err) {
    console.error('领取失败', err);
    status.value = `❌ 领取失败: ${err.message}`;
    isError.value = true;
  } finally {
    isProcessing.value = false;
  }
}

async function handleRefund() {
  if (!wallet?.sdk || !selectedCampaign.value || !wallet?.account) return;
  isProcessing.value = true;
  status.value = '⏳ 正在申请退款...';
  isError.value = false;

  try {
    await wallet.sdk.refundCampaign(selectedCampaign.value, wallet.account);
    status.value = '✅ 退款成功';
    await selectCampaign(selectedCampaign.value);
  } catch (err) {
    console.error('退款失败', err);
    status.value = `❌ 退款失败: ${err.message}`;
    isError.value = true;
  } finally {
    isProcessing.value = false;
  }
}

async function handleWithdrawRaised() {
  if (!wallet?.sdk || !selectedCampaign.value || !wallet?.account) return;
  isProcessing.value = true;
  status.value = '⏳ 正在提取募集款...';
  isError.value = false;

  try {
    await wallet.sdk.withdrawRaised(selectedCampaign.value, wallet.account);
    status.value = '✅ 募集款提取成功';
    await selectCampaign(selectedCampaign.value);
  } catch (err) {
    console.error('提取失败', err);
    status.value = `❌ 提取失败: ${err.message}`;
    isError.value = true;
  } finally {
    isProcessing.value = false;
  }
}

async function handleWithdrawDeposit() {
  if (!wallet?.sdk || !selectedCampaign.value || !wallet?.account) return;
  isProcessing.value = true;
  status.value = '⏳ 正在提取保证金...';
  isError.value = false;

  try {
    await wallet.sdk.withdrawDeposit(selectedCampaign.value, wallet.account);
    status.value = '✅ 保证金提取成功';
    await selectCampaign(selectedCampaign.value);
  } catch (err) {
    console.error('提取失败', err);
    status.value = `❌ 提取失败: ${err.message}`;
    isError.value = true;
  } finally {
    isProcessing.value = false;
  }
}
</script>

<style scoped>
.crowd-root {
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 14px;
}

/* 工厂信息标签 */
.factory-tags {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
}

.ftag {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 7px 12px;
  border-radius: 999px;
  background: rgba(248, 250, 252, 0.96);
  border: 1px solid rgba(226, 232, 240, 0.95);
  font-size: 0.78rem;
}

.ftag-label {
  font-weight: 700;
  color: #64748b;
  font-size: 0.72rem;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.ftag-value {
  font-size: 0.76rem;
  font-family: ui-monospace, monospace;
  word-break: break-all;
}

.ftag-highlight {
  background: rgba(22, 163, 74, 0.06);
  border-color: rgba(22, 163, 74, 0.2);
}

.ftag-highlight .ftag-value {
  color: #16a34a;
  font-family: inherit;
}

/* 工作区布局 */
.crowd-workspace {
  display: grid;
  grid-template-columns: minmax(0, 280px) minmax(0, 1fr);
  gap: 14px;
  align-items: start;
}

.crowd-sidebar {
  display: flex;
  flex-direction: column;
  gap: 12px;
  min-width: 0;
}

.crowd-main {
  min-width: 0;
}

/* 盒子通用 */
.box {
  padding: 14px 16px;
  border: 1px solid rgba(226, 232, 240, 0.95);
  border-radius: 14px;
  background: rgba(248, 250, 252, 0.96);
}

.box-header {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-bottom: 12px;
}

.box-icon {
  font-size: 0.95rem;
}

.box-header h3 {
  margin: 0;
  font-size: 0.95rem;
  font-weight: 750;
  color: #0f172a;
  flex: 1;
}

.count-badge {
  font-size: 0.7rem;
  font-weight: 800;
  background: rgba(37, 99, 235, 0.12);
  color: #2563eb;
  padding: 2px 8px;
  border-radius: 999px;
}

/* 创建表单 */
.field-grid {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-bottom: 12px;
}

.field-row {
  display: flex;
  align-items: center;
  gap: 10px;
}

.field-row label {
  width: 110px;
  flex-shrink: 0;
  font-size: 0.82rem;
  color: #334155;
  font-weight: 650;
}

.field-row input {
  flex: 1;
  min-width: 0;
  padding: 8px 10px;
  border: 1px solid rgba(148, 163, 184, 0.45);
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.95);
  outline: none;
  font-size: 0.85rem;
  transition: box-shadow 140ms ease, border-color 140ms ease;
}

.field-row input:focus {
  border-color: rgba(59, 130, 246, 0.65);
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.15);
}

/* Campaign 列表 */
.campaign-list {
  max-height: 220px;
  overflow-y: auto;
  padding: 0;
  margin: 0;
  list-style: none;
  border: 1px solid rgba(148, 163, 184, 0.3);
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.55);
}

.campaign-list li {
  padding: 9px 12px;
  cursor: pointer;
  border-bottom: 1px solid rgba(226, 232, 240, 0.7);
  font-family: ui-monospace, monospace;
  font-size: 0.76rem;
  color: #0f172a;
  display: flex;
  align-items: center;
  gap: 8px;
  transition: background 120ms ease;
}

.campaign-list li:hover {
  background: rgba(226, 232, 240, 0.45);
}

.campaign-list li:last-child {
  border-bottom: none;
}

.campaign-list li.selected {
  background: rgba(224, 242, 254, 0.9);
}

.campaign-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: #94a3b8;
  flex-shrink: 0;
}

.campaign-list li.selected .campaign-dot {
  background: #2563eb;
  box-shadow: 0 0 6px rgba(37, 99, 235, 0.4);
}

.campaign-addr {
  word-break: break-all;
  line-height: 1.3;
}

.empty {
  color: #64748b;
  font-size: 0.85rem;
  margin: 0;
  text-align: center;
  padding: 8px 0;
}

/* 空详情提示 */
.empty-detail {
  padding: 32px 20px;
  text-align: center;
  color: #64748b;
  font-size: 0.9rem;
}

.empty-detail .empty-icon {
  font-size: 2rem;
  margin-bottom: 8px;
}

.empty-detail p {
  margin: 0;
}

/* Campaign 详情 */
.campaign-detail {
  padding: 16px;
}

.detail-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 14px;
}

.detail-header h3 {
  margin: 0;
  font-size: 1rem;
  font-weight: 750;
  color: #0f172a;
}

.status-badge {
  font-size: 0.75rem;
  font-weight: 700;
  padding: 4px 12px;
  border-radius: 999px;
  white-space: nowrap;
}

.badge-active {
  background: rgba(59, 130, 246, 0.1);
  color: #2563eb;
}

.badge-success {
  background: rgba(22, 163, 74, 0.1);
  color: #16a34a;
}

.badge-fail {
  background: rgba(239, 68, 68, 0.1);
  color: #dc2626;
}

/* 募集进度 */
.progress-section {
  background: rgba(248, 250, 252, 0.96);
  border: 1px solid rgba(226, 232, 240, 0.8);
  border-radius: 12px;
  padding: 12px 14px;
  margin-bottom: 14px;
}

.progress-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
}

.progress-label {
  font-size: 0.82rem;
  font-weight: 700;
  color: #334155;
}

.progress-value {
  font-size: 0.85rem;
  font-weight: 700;
  color: #0f172a;
  font-variant-numeric: tabular-nums;
}

.progress-bar {
  height: 10px;
  border-radius: 999px;
  background: rgba(226, 232, 240, 0.8);
  overflow: hidden;
  margin-bottom: 8px;
}

.progress-fill {
  height: 100%;
  border-radius: 999px;
  background: linear-gradient(90deg, #3b82f6, #2563eb);
  transition: width 0.5s ease;
  min-width: 0;
}

.progress-meta {
  display: flex;
  gap: 16px;
  font-size: 0.76rem;
  color: #94a3b8;
}

/* 详情网格 */
.detail-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
  margin-bottom: 14px;
}

.detail-item {
  background: rgba(248, 250, 252, 0.96);
  border: 1px solid rgba(226, 232, 240, 0.8);
  border-radius: 10px;
  padding: 10px 12px;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.di-label {
  font-size: 0.72rem;
  font-weight: 700;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.di-value {
  font-size: 0.8rem;
  font-family: ui-monospace, monospace;
  word-break: break-all;
  color: #0f172a;
}

/* 我的参与 */
.user-section {
  background: linear-gradient(135deg, rgba(37, 99, 235, 0.05), rgba(99, 102, 241, 0.03));
  border: 1px solid rgba(37, 99, 235, 0.12);
  border-radius: 12px;
  padding: 12px 14px;
  margin-bottom: 14px;
}

.user-section h4 {
  margin: 0 0 10px;
  font-size: 0.88rem;
  font-weight: 750;
  color: #1e40af;
}

.user-stats {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
}

.us-item {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.us-label {
  font-size: 0.72rem;
  font-weight: 700;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.us-value {
  font-size: 0.95rem;
  font-weight: 800;
  color: #0f172a;
  font-variant-numeric: tabular-nums;
}

/* 认购输入 */
.pledge-section {
  margin-bottom: 14px;
}

.pledge-section label {
  display: block;
  font-size: 0.82rem;
  font-weight: 700;
  color: #334155;
  margin-bottom: 6px;
}

.pledge-row {
  display: flex;
  gap: 10px;
}

.pledge-row input {
  flex: 1;
  min-width: 0;
  padding: 10px 12px;
  border-radius: 12px;
  border: 1px solid rgba(148, 163, 184, 0.45);
  background: rgba(255, 255, 255, 0.95);
  outline: none;
  font-size: 0.9rem;
  transition: box-shadow 140ms ease, border-color 140ms ease;
}

.pledge-row input:focus {
  border-color: rgba(59, 130, 246, 0.65);
  box-shadow: 0 0 0 4px rgba(59, 130, 246, 0.15);
}

/* 操作按钮区 */
.actions-area {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-bottom: 14px;
}

.actions-group h4 {
  margin: 0 0 8px;
  font-size: 0.82rem;
  font-weight: 700;
  color: #64748b;
}

.actions-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

/* 通用按钮 */
.action-btn {
  padding: 9px 16px;
  border: none;
  border-radius: 10px;
  color: white;
  cursor: pointer;
  font-weight: 700;
  font-size: 0.82rem;
  white-space: nowrap;
  box-shadow: 0 4px 12px rgba(2, 6, 23, 0.1);
  transition: transform 0.12s ease, filter 0.12s ease, opacity 0.12s ease;
}

.action-btn:hover:not(:disabled) {
  transform: translateY(-1px);
  filter: brightness(1.02);
}

.action-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
  box-shadow: none;
}

.create-btn {
  background: linear-gradient(180deg, #16a34a, #15803d);
  width: 100%;
  padding: 11px 16px;
  font-size: 0.88rem;
  border-radius: 12px;
}

.btn-icon {
  font-size: 0.9rem;
}

.pledge-btn {
  background: linear-gradient(180deg, #2563eb, #1d4ed8);
}

.claim-btn {
  background: linear-gradient(180deg, #8b5cf6, #6d28d9);
}

.warn-btn {
  background: linear-gradient(180deg, #ef4444, #b91c1c);
}

.primary-btn {
  background: linear-gradient(180deg, #16a34a, #15803d);
}

.withdraw-btn {
  background: linear-gradient(180deg, #f59e0b, #d97706);
}

.deposit-btn {
  background: linear-gradient(180deg, #6366f1, #4338ca);
}

/* 提取状态 */
.withdraw-status {
  display: flex;
  gap: 12px;
  padding: 10px 14px;
  border-radius: 10px;
  background: rgba(248, 250, 252, 0.96);
  border: 1px solid rgba(226, 232, 240, 0.8);
  font-size: 0.78rem;
  color: #94a3b8;
}

.ws-item {
  display: flex;
  align-items: center;
  gap: 4px;
}

.ws-item.done {
  color: #16a34a;
}

/* 状态消息 */
.status-msg {
  margin-top: 4px;
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

@media (max-width: 900px) {
  .crowd-workspace {
    grid-template-columns: 1fr;
  }

  .field-row {
    flex-direction: column;
    align-items: stretch;
  }

  .field-row label {
    width: auto;
  }

  .detail-grid {
    grid-template-columns: 1fr;
  }

  .actions-row {
    flex-direction: column;
  }

  .action-btn {
    width: 100%;
    text-align: center;
  }
}
</style>