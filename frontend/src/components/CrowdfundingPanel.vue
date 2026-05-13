<template>
  <div class="crowdfunding-container">
    <h2>众筹工厂 / Campaign 管理</h2>

    <button v-if="!account" @click="connectWallet" class="connect-btn">连接钱包</button>

    <div v-else>
      <p class="account-info">当前账号: <code>{{ shortAddress }}</code></p>

      <div class="factory-summary">
        <p>工厂地址: <code>{{ factoryInfo.address }}</code></p>
        <p>金库地址: <code>{{ factoryInfo.globalVault }}</code></p>
        <p>最小保证金: <strong>{{ factoryInfo.minDeposit }} ETH</strong></p>
      </div>

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
        <button @click="handleCreateCampaign" :disabled="isProcessing || !canCreate" class="action-btn">创建 Campaign</button>
      </section>

      <section class="box">
        <h3>已发布 Campaign</h3>
        <div v-if="campaigns.length === 0" class="empty">暂无 Campaign，先创建一个。</div>
        <ul class="campaign-list">
          <li
            v-for="address in campaigns"
            :key="address"
            :class="{ selected: selectedCampaign === address }"
            @click="selectCampaign(address)">
            {{ address }}
          </li>
        </ul>
      </section>

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

        <div class="actions-grid">
          <div class="field-row small">
            <label>认购 ETH</label>
            <input v-model="pledgeAmount" type="number" step="0.01" min="0" placeholder="输入 ETH" />
          </div>
          <button @click="handlePledge" :disabled="isProcessing || !pledgeAmount" class="action-btn">认购</button>
          <button @click="handleClaim" :disabled="isProcessing || !selectedCampaignInfo.finalized || !selectedCampaignInfo.success" class="action-btn">Claim</button>
          <button @click="handleRefund" :disabled="isProcessing || !selectedCampaignInfo.finalized || selectedCampaignInfo.success" class="action-btn warn">退款</button>
          <button @click="handleFinalize" :disabled="isProcessing || !canFinalize" class="action-btn primary">Finalize</button>
          <button @click="handleWithdrawRaised" :disabled="isProcessing || !canWithdrawRaised" class="action-btn">提取募集款</button>
          <button @click="handleWithdrawDeposit" :disabled="isProcessing || !canWithdrawDeposit" class="action-btn">提取保证金</button>
        </div>
      </section>
    </div>

    <div v-if="status" :class="['status-msg', { error: isError }]">
      {{ status }}
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { createStakingSDK } from '../sdk/index.js';
import { CROWDFUND_FACTORY_ADDR } from '../sdk/contract.js';

const account = ref(null);
const status = ref('');
const isProcessing = ref(false);
const isError = ref(false);
const sdk = ref(null);

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

const shortAddress = computed(() =>
  account.value ? `${account.value.slice(0, 6)}...${account.value.slice(-4)}` : ''
);

const canCreate = computed(() => {
  return createTarget.value > 0 && createTotalToken.value > 0 && createRatio.value > 0 && createName.value && createSymbol.value && createDeposit.value > 0;
});

const canFinalize = computed(() => {
  return selectedCampaignInfo.value && selectedCampaignInfo.value.creator.toLowerCase() === account.value.toLowerCase() && !selectedCampaignInfo.value.finalized;
});

const canWithdrawRaised = computed(() => {
  return selectedCampaignInfo.value && selectedCampaignInfo.value.creator.toLowerCase() === account.value.toLowerCase() && selectedCampaignInfo.value.finalized && selectedCampaignInfo.value.success && !selectedCampaignInfo.value.raisedWithdrawn;
});

const canWithdrawDeposit = computed(() => {
  return selectedCampaignInfo.value && selectedCampaignInfo.value.creator.toLowerCase() === account.value.toLowerCase() && selectedCampaignInfo.value.finalized && !selectedCampaignInfo.value.depositWithdrawn;
});

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
    factoryInfo.value.address = CROWDFUND_FACTORY_ADDR;
    await refreshFactory();
    await refreshCampaigns();
    status.value = '✅ 钱包已连接';
    isError.value = false;
  } catch (err) {
    status.value = `❌ 连接失败: ${err.message}`;
    isError.value = true;
  }
}

onMounted(() => {
  const handleAccountsChanged = (accounts) => {
    const next = accounts?.[0] ?? null;
    account.value = next;

    if (!next) {
      sdk.value = null;
      campaigns.value = [];
      selectedCampaign.value = '';
      selectedCampaignInfo.value = null;
      selectedUserInfo.value = { contribution: '0', ethContributed: '0' };
      status.value = '钱包已断开连接';
      isError.value = false;
      return;
    }

    sdk.value = createStakingSDK(window.ethereum);
    refreshFactory();
    refreshCampaigns();
    if (selectedCampaign.value) selectCampaign(selectedCampaign.value);
  };

  const handleChainChanged = () => {
    if (!account.value) return;
    sdk.value = createStakingSDK(window.ethereum);
    refreshFactory();
    refreshCampaigns();
    if (selectedCampaign.value) selectCampaign(selectedCampaign.value);
  };

  if (window.ethereum?.on) {
    window.ethereum.on('accountsChanged', handleAccountsChanged);
    window.ethereum.on('chainChanged', handleChainChanged);
  }

  onUnmounted(() => {
    if (window.ethereum?.removeListener) {
      window.ethereum.removeListener('accountsChanged', handleAccountsChanged);
      window.ethereum.removeListener('chainChanged', handleChainChanged);
    }
  });
});

async function refreshFactory() {
  if (!sdk.value) return;
  try {
    const info = await sdk.value.getFactoryInfo();
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
  if (!sdk.value) return;
  try {
    campaigns.value = await sdk.value.getFactoryCampaigns(20);
  } catch (err) {
    console.error('获取 Campaign 列表失败', err);
  }
}

async function selectCampaign(address) {
  if (!sdk.value || !address) return;
  selectedCampaign.value = address;
  try {
    selectedCampaignInfo.value = await sdk.value.getCampaignInfo(address);
    selectedUserInfo.value = await sdk.value.getCampaignUserInfo(address, account.value);
  } catch (err) {
    console.error('加载 Campaign 详情失败', err);
    status.value = `❌ 加载 Campaign 失败: ${err.message}`;
    isError.value = true;
  }
}

async function handleCreateCampaign() {
  if (!sdk.value) return;
  isProcessing.value = true;
  status.value = '⏳ 正在创建 Campaign...';
  isError.value = false;

  try {
    const before = new Set(campaigns.value);
    await sdk.value.createCampaign(
      account.value,
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
  if (!sdk.value || !selectedCampaign.value) return;
  isProcessing.value = true;
  status.value = '⏳ 正在认购...';
  isError.value = false;

  try {
    await sdk.value.pledge(selectedCampaign.value, account.value, String(pledgeAmount.value ?? '0'));
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
  if (!sdk.value || !selectedCampaign.value) return;
  isProcessing.value = true;
  status.value = '⏳ 正在终结 Campaign...';
  isError.value = false;

  try {
    await selectCampaign(selectedCampaign.value);
    if (!selectedCampaignInfo.value) {
      throw new Error('无法获取选中 Campaign 详情');
    }
    if (selectedCampaignInfo.value.creator.toLowerCase() !== account.value.toLowerCase()) {
      throw new Error('当前连接账号不是该 Campaign 的创建者');
    }

    await sdk.value.finalizeCampaign(selectedCampaign.value, account.value);
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
  if (!sdk.value || !selectedCampaign.value) return;
  isProcessing.value = true;
  status.value = '⏳ 正在领取项目代币...';
  isError.value = false;

  try {
    await sdk.value.claimCampaign(selectedCampaign.value, account.value);
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
  if (!sdk.value || !selectedCampaign.value) return;
  isProcessing.value = true;
  status.value = '⏳ 正在申请退款...';
  isError.value = false;

  try {
    await sdk.value.refundCampaign(selectedCampaign.value, account.value);
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
  if (!sdk.value || !selectedCampaign.value) return;
  isProcessing.value = true;
  status.value = '⏳ 正在提取募集款...';
  isError.value = false;

  try {
    await sdk.value.withdrawRaised(selectedCampaign.value, account.value);
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
  if (!sdk.value || !selectedCampaign.value) return;
  isProcessing.value = true;
  status.value = '⏳ 正在提取保证金...';
  isError.value = false;

  try {
    await sdk.value.withdrawDeposit(selectedCampaign.value, account.value);
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
.crowdfunding-container {
  padding: 26px 22px;
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.92);
  border: 1px solid rgba(226, 232, 240, 0.8);
  box-shadow: 0 18px 45px rgba(2, 6, 23, 0.28);
  backdrop-filter: blur(10px);
}

.factory-summary,
.box {
  padding: 16px 16px;
  border: 1px solid rgba(226, 232, 240, 0.9);
  border-radius: 14px;
  margin-bottom: 16px;
  background: rgba(248, 250, 252, 0.92);
}

.crowdfunding-container h2 {
  margin: 2px 0 18px;
  font-size: 1.2rem;
  letter-spacing: 0.2px;
}

.account-info {
  margin-bottom: 14px;
  color: #334155;
}

.account-info code,
.factory-summary code {
  padding: 2px 8px;
  border-radius: 999px;
  background: rgba(148, 163, 184, 0.18);
  border: 1px solid rgba(148, 163, 184, 0.28);
}

.factory-summary p {
  margin: 6px 0;
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
}

.factory-summary strong {
  font-variant-numeric: tabular-nums;
}

.field-row {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 12px;
}

.field-row.small {
  max-width: 320px;
}

.field-row label {
  width: 140px;
  font-size: 0.95rem;
  color: #334155;
  font-weight: 650;
}

.field-row input {
  flex: 1;
  padding: 10px 12px;
  border: 1px solid rgba(148, 163, 184, 0.45);
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.9);
  outline: none;
  transition: box-shadow 140ms ease, border-color 140ms ease;
}

.field-row input:focus {
  border-color: rgba(59, 130, 246, 0.65);
  box-shadow: 0 0 0 4px rgba(59, 130, 246, 0.22);
}

.action-btn {
  margin-top: 10px;
  padding: 12px 16px;
  border: none;
  border-radius: 12px;
  background: linear-gradient(180deg, #2563eb, #1d4ed8);
  color: white;
  cursor: pointer;
  font-weight: 750;
  letter-spacing: 0.2px;
  box-shadow: 0 10px 20px rgba(2, 6, 23, 0.14);
  transition: transform 120ms ease, filter 120ms ease, box-shadow 120ms ease, opacity 120ms ease;
}

.action-btn:hover:not(:disabled) {
  transform: translateY(-1px);
  filter: brightness(1.02);
  box-shadow: 0 14px 28px rgba(2, 6, 23, 0.18);
}

.action-btn:active:not(:disabled) {
  transform: translateY(0px);
}

.action-btn:disabled {
  opacity: 0.55;
  cursor: not-allowed;
  box-shadow: none;
}

.action-btn.warn {
  background: linear-gradient(180deg, #ef4444, #b91c1c);
}

.action-btn.primary {
  background: linear-gradient(180deg, #16a34a, #15803d);
}

.campaign-list {
  max-height: 220px;
  overflow-y: auto;
  padding: 0;
  list-style: none;
  border: 1px solid rgba(148, 163, 184, 0.35);
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.55);
}

.campaign-list li {
  padding: 12px 14px;
  cursor: pointer;
  border-bottom: 1px solid rgba(226, 232, 240, 0.9);
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
  font-size: 0.9rem;
  color: #0f172a;
  transition: background 140ms ease;
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
}

.status-msg {
  margin-top: 18px;
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

.actions-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
  gap: 12px;
  margin-top: 14px;
}

.campaign-detail p,
.user-info p {
  margin: 6px 0;
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
  font-variant-numeric: tabular-nums;
}

.campaign-detail p strong,
.user-info p strong {
  color: #334155;
  font-weight: 700;
}

.user-info {
  margin-top: 14px;
  padding-top: 12px;
  border-top: 1px dashed rgba(148, 163, 184, 0.45);
}

@media (max-width: 640px) {
  .crowdfunding-container {
    padding: 20px 16px;
    border-radius: 16px;
  }
  .field-row {
    flex-direction: column;
    align-items: stretch;
  }
  .field-row label {
    width: auto;
  }
  .field-row.small {
    max-width: none;
  }
  .actions-grid {
    grid-template-columns: 1fr;
  }
}
</style>
