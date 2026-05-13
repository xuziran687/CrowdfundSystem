<template>
  <div class="crowd-root">
    <div class="factory-summary">
      <p>工厂地址: <code>{{ factoryInfo.address }}</code></p>
      <p>金库地址: <code>{{ factoryInfo.globalVault }}</code></p>
      <p>最小保证金: <strong>{{ factoryInfo.minDeposit }} ETH</strong></p>
    </div>

    <div class="crowd-workspace">
      <aside class="crowd-sidebar">
        <section class="box">
          <h3>发起新 Campaign</h3>
          <div class="field-row">
            <label>目标 ETH</label>
            <input v-model="createTarget" type="number" step="0.01" min="0" placeholder="目标 ETH" />
          </div>
          <div class="field-row">
            <label>发行总量</label>
            <input v-model="createTotalToken" type="number" step="1" min="0" placeholder="总代币数量" />
          </div>
          <div class="field-row">
            <label>最高抵扣比例 (BPS)</label>
            <input v-model="createRatio" type="number" step="1" min="0" placeholder="如 3000 表示 30%" />
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
          <button type="button" @click="handleCreateCampaign" :disabled="isProcessing || !canCreate" class="action-btn">创建 Campaign</button>
        </section>

        <section class="box">
          <h3>已发布 Campaign</h3>
          <div v-if="campaigns.length === 0" class="empty">暂无 Campaign，先创建一个。</div>
          <ul v-else class="campaign-list">
            <li
              v-for="address in campaigns"
              :key="address"
              :class="{ selected: selectedCampaign === address }"
              @click="selectCampaign(address)"
            >
              {{ address }}
            </li>
          </ul>
        </section>
      </aside>

      <div class="crowd-main">
        <section v-if="selectedCampaignInfo" class="box campaign-detail">
          <h3>Campaign 详情</h3>
          <p><strong>地址:</strong> {{ selectedCampaign }}</p>
          <p><strong>创建者:</strong> {{ selectedCampaignInfo.creator }}</p>
          <p><strong>目标:</strong> {{ selectedCampaignInfo.target }} ETH</p>
          <p><strong>已筹金额:</strong> {{ selectedCampaignInfo.raised }} ETH</p>
          <p><strong>名义总额:</strong> {{ selectedCampaignInfo.totalContribution }} ETH</p>
          <p><strong>抵扣上限:</strong> {{ selectedCampaignInfo.maxDeductionRatio }} BPS</p>
          <p><strong>保证金:</strong> {{ selectedCampaignInfo.deposit }} ETH</p>
          <p><strong>是否已终结:</strong> {{ selectedCampaignInfo.finalized }}</p>
          <p><strong>是否成功:</strong> {{ selectedCampaignInfo.success }}</p>
          <p><strong>募集款已提取:</strong> {{ selectedCampaignInfo.raisedWithdrawn }}</p>
          <p><strong>保证金已提取:</strong> {{ selectedCampaignInfo.depositWithdrawn }}</p>
          <p><strong>项目代币合约:</strong> {{ selectedCampaignInfo.tokenAddress }}</p>

          <div class="user-info">
            <h4>我的参与</h4>
            <p><strong>名义贡献:</strong> {{ selectedUserInfo.contribution }} ETH</p>
            <p><strong>实际支付 ETH:</strong> {{ selectedUserInfo.ethContributed }} ETH</p>
          </div>
          <div class="field-row small">
              <label>认购 ETH</label>
              <input v-model="pledgeAmount" type="number" step="0.01" min="0" placeholder="输入 ETH" />
            </div>
          <div class="actions-grid">
            
            <button type="button" @click="handlePledge" :disabled="isProcessing || !pledgeAmount" class="action-btn">认购</button>
            <button type="button" @click="handleClaim" :disabled="isProcessing || !selectedCampaignInfo.finalized || !selectedCampaignInfo.success" class="action-btn">Claim</button>
            <button type="button" @click="handleRefund" :disabled="isProcessing || !selectedCampaignInfo.finalized || selectedCampaignInfo.success" class="action-btn warn">退款</button>
            <button type="button" @click="handleFinalize" :disabled="isProcessing || !canFinalize" class="action-btn primary">Finalize</button>
            <button type="button" @click="handleWithdrawRaised" :disabled="isProcessing || !canWithdrawRaised" class="action-btn">提取募集款</button>
            <button type="button" @click="handleWithdrawDeposit" :disabled="isProcessing || !canWithdrawDeposit" class="action-btn">提取保证金</button>
          </div>
        </section>
        <div v-else class="empty-detail box">
          <p>在左侧列表中选择一个 Campaign 查看详情与操作。</p>
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
    status.value = '✅ 领取成功';
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
}

.factory-summary {
  padding: 14px 16px;
  border: 1px solid rgba(226, 232, 240, 0.95);
  border-radius: 14px;
  margin-bottom: 16px;
  background: rgba(248, 250, 252, 0.96);
}

.factory-summary p {
  margin: 6px 0;
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
  font-size: 0.9rem;
}

.factory-summary code {
  padding: 2px 8px;
  border-radius: 999px;
  background: rgba(148, 163, 184, 0.18);
  border: 1px solid rgba(148, 163, 184, 0.28);
  font-size: 0.78rem;
}

.factory-summary strong {
  font-variant-numeric: tabular-nums;
}

.crowd-workspace {
  display: grid;
  grid-template-columns: minmax(0, 300px) minmax(0, 1fr);
  gap: 18px;
  align-items: start;
}

.crowd-sidebar {
  display: flex;
  flex-direction: column;
  gap: 14px;
  min-width: 0;
}

.crowd-main {
  min-width: 0;
}

.empty-detail {
  padding: 28px 20px;
  text-align: center;
  color: #64748b;
  font-size: 0.95rem;
}

.empty-detail p {
  margin: 0;
}

.box {
  padding: 14px 16px;
  border: 1px solid rgba(226, 232, 240, 0.95);
  border-radius: 14px;
  background: rgba(248, 250, 252, 0.96);
}

.box h3 {
  margin: 0 0 12px;
  font-size: 1rem;
  font-weight: 750;
  color: #0f172a;
}

.field-row {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 10px;
}

.field-row.small {
  max-width: 100%;
}

.field-row label {
  width: 132px;
  flex-shrink: 0;
  font-size: 0.88rem;
  color: #334155;
  font-weight: 650;
}

.field-row input {
  flex: 1;
  min-width: 0;
  padding: 9px 11px;
  border: 1px solid rgba(148, 163, 184, 0.45);
  border-radius: 11px;
  background: rgba(255, 255, 255, 0.95);
  outline: none;
}

.field-row input:focus {
  border-color: rgba(59, 130, 246, 0.65);
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.2);
}

.action-btn {
  margin-top: 8px;
  padding: 11px 16px;
  border: none;
  border-radius: 12px;
  background: linear-gradient(180deg, #2563eb, #1d4ed8);
  color: white;
  cursor: pointer;
  font-weight: 750;
  font-size: 0.9rem;
  box-shadow: 0 8px 18px rgba(2, 6, 23, 0.12);
  transition: transform 0.12s ease, filter 0.12s ease, opacity 0.12s ease;
}

.action-btn:hover:not(:disabled) {
  transform: translateY(-1px);
  filter: brightness(1.02);
}

.action-btn:disabled {
  opacity: 0.55;
  cursor: not-allowed;
}

.action-btn.warn {
  background: linear-gradient(180deg, #ef4444, #b91c1c);
}

.action-btn.primary {
  background: linear-gradient(180deg, #16a34a, #15803d);
}

.campaign-list {
  max-height: 240px;
  overflow-y: auto;
  padding: 0;
  margin: 0;
  list-style: none;
  border: 1px solid rgba(148, 163, 184, 0.35);
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.55);
}

.campaign-list li {
  padding: 10px 12px;
  cursor: pointer;
  border-bottom: 1px solid rgba(226, 232, 240, 0.9);
  font-family: ui-monospace, monospace;
  font-size: 0.78rem;
  color: #0f172a;
  word-break: break-all;
}

.campaign-list li:hover {
  background: rgba(226, 232, 240, 0.55);
}

.campaign-list li:last-child {
  border-bottom: none;
}

.campaign-list li.selected {
  background: rgba(224, 242, 254, 0.95);
}

.empty {
  color: #64748b;
  font-size: 0.9rem;
  margin: 0;
}

.campaign-detail h3 {
  margin-top: 0;
}

.campaign-detail p,
.user-info p {
  margin: 6px 0;
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 10px;
  font-size: 0.88rem;
  font-variant-numeric: tabular-nums;
}

.campaign-detail p strong,
.user-info p strong {
  color: #334155;
  font-weight: 700;
}

.user-info {
  margin-top: 12px;
  padding-top: 12px;
  border-top: 1px dashed rgba(148, 163, 184, 0.45);
}

.user-info h4 {
  margin: 0 0 8px;
  font-size: 0.95rem;
}.pledge-input-row {
  margin-bottom: 12px;
}
.actions-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
  gap: 10px;
  margin-top: 12px;
}

.status-msg {
  margin-top: 16px;
  padding: 12px 14px;
  border-radius: 12px;
  background: rgba(239, 246, 255, 0.95);
  border: 1px solid rgba(59, 130, 246, 0.26);
  color: #0f172a;
  font-size: 0.9rem;
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

  .actions-grid {
    grid-template-columns: 1fr;
  }
}
</style>
