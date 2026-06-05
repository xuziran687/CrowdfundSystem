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
              <label>持续时间</label>
              <div class="duration-inputs">
                <div class="dur-field">
                  <input v-model="createDays" type="number" min="0" placeholder="0" />
                  <span class="dur-unit">天</span>
                </div>
                <div class="dur-field">
                  <input v-model="createHours" type="number" min="0" max="23" placeholder="0" />
                  <span class="dur-unit">时</span>
                </div>
                <div class="dur-field">
                  <input v-model="createMinutes" type="number" min="0" max="59" placeholder="0" />
                  <span class="dur-unit">分</span>
                </div>
              </div>
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
            <span :class="['status-badge', selectedCampaignInfo.finalized ? (selectedCampaignInfo.success ? 'badge-success' : 'badge-fail') : (isExpiredNow ? 'badge-expired' : 'badge-active')]">
              {{ selectedCampaignInfo.finalized ? (selectedCampaignInfo.success ? '✅ 成功' : '❌ 失败') : (isExpiredNow ? '⏰ 已到期' : '🔄 进行中') }}
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
              <span>参与人数: {{ selectedCampaignInfo.contributorsCount }}</span>
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
            <div class="detail-item">
              <span class="di-label">截止时间</span>
              <strong :class="['di-value', { 'text-red': isExpiredNow }]">
                {{ formatDeadline(selectedCampaignInfo.deadline) }}
                {{ isExpiredNow ? '（已过期）' : '' }}
              </strong>
            </div>
          </div>

          <!-- ===== 创建者视图 ===== -->
          <template v-if="isCreator">
            <!-- 创建者信息 -->
            <div class="user-section creator-section">
              <h4>👑 创建者面板</h4>
              <div class="user-stats">
                <div class="us-item">
                  <span class="us-label">保证金</span>
                  <strong class="us-value">{{ selectedCampaignInfo.deposit }} ETH</strong>
                </div>
                <div class="us-item">
                  <span class="us-label">募集款</span>
                  <strong class="us-value">{{ selectedCampaignInfo.raised }} ETH</strong>
                </div>
              </div>
            </div>

            <!-- 创建者操作 -->
            <div class="actions-area">
              <div class="actions-group">
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
                  <button v-if="selectedCampaignInfo.success && selectedCampaignInfo.finalized" type="button" @click="handleSweepTokens" :disabled="isProcessing || selectedCampaignInfo.tokensSwept || !canSweepTokens" class="action-btn deposit-btn">
                    {{ selectedCampaignInfo.tokensSwept ? '✅ 已扫回' : '🧹 扫回未领取代币' }}
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
          </template>

          <!-- ===== 非创建者视图（参与者 / 浏览者） ===== -->
          <template v-else>
            <!-- 我的参与 -->
            <div class="user-section" v-if="hasParticipated">
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

            <!-- 认购输入（进行中 & 未过期才显示） -->
            <div class="pledge-section" v-if="!selectedCampaignInfo.finalized && !isExpiredNow">
              <div class="pledge-input">
                <label>认购金额</label>
                <div class="pledge-row">
                  <input v-model="pledgeAmount" type="number" step="0.01" min="0" placeholder="输入 ETH" />
                  <button type="button" @click="handlePledge" :disabled="isProcessing || !pledgeAmount" class="action-btn pledge-btn">认购</button>
                </div>
              </div>
            </div>

            <!-- 参与者操作 -->
            <div class="actions-area">
              <!-- 众筹成功 → 领取代币 -->
              <div class="actions-group" v-if="selectedCampaignInfo.success && selectedCampaignInfo.finalized">
                <h4>参与者操作</h4>
                <div class="actions-row">
                  <button v-if="hasParticipated" type="button" @click="handleClaim" :disabled="isProcessing || hasClaimed" class="action-btn claim-btn">
                    {{ hasClaimed ? '✅ 已领取' : '🪙 领取代币' }}
                  </button>
                  <div v-if="!hasParticipated" class="auto-refund-notice">
                    ℹ️ 你未参与此众筹
                  </div>
                </div>
              </div>

              <!-- 众筹失败 → 退款 -->
              <div class="actions-group" v-if="!selectedCampaignInfo.success && selectedCampaignInfo.finalized">
                <h4>参与者操作</h4>
                <div class="actions-row">
                  <div v-if="hasRefunded" class="auto-refund-notice">
                    💰 退款已到账
                  </div>
                  <button v-else-if="hasParticipated" type="button" @click="handleClaimRefund" :disabled="isProcessing" class="action-btn warn-btn">
                    💰 手动领取退款
                  </button>
                  <div v-else class="auto-refund-notice">
                    ℹ️ 你未参与此众筹
                  </div>
                </div>
              </div>

              <!-- 众筹进行中且已过期 → 任何人都可结束 -->
              <div class="actions-group" v-if="isExpiredNow && !selectedCampaignInfo.finalized">
                <h4>到期操作</h4>
                <div class="actions-row">
                  <button type="button" @click="handleFinalize" :disabled="isProcessing" class="action-btn primary-btn">
                    ⏹ 结束众筹
                  </button>
                </div>
              </div>
            </div>
          </template>
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

// 实时时间戳（每秒刷新），用于前端即时判断过期
const nowTs = ref(Math.floor(Date.now() / 1000));
const nowTimer = setInterval(() => { nowTs.value = Math.floor(Date.now() / 1000); }, 1000);
onUnmounted(() => clearInterval(nowTimer));

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
const createDays = ref('');
const createHours = ref('');
const createMinutes = ref('');
const createDeposit = ref('0');
const pledgeAmount = ref('');

let campaignsPollTimer = null;

function formatDeadline(timestamp) {
  if (!timestamp) return '未设置';
  const date = new Date(timestamp * 1000);
  return date.toLocaleString('zh-CN', { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' });
}

function stopCampaignPoll() {
  if (campaignsPollTimer) {
    clearInterval(campaignsPollTimer);
    campaignsPollTimer = null;
  }
}

const canCreate = computed(() => {
  const hasDuration = (Number(createDays.value) || 0) + (Number(createHours.value) || 0) + (Number(createMinutes.value) || 0) > 0;
  return createTarget.value > 0 && createTotalToken.value > 0 && createRatio.value > 0 && createName.value && createSymbol.value && createDeposit.value > 0 && hasDuration;
});

const canFinalize = computed(() => {
  const acc = wallet?.account;
  if (!selectedCampaignInfo.value || !acc || selectedCampaignInfo.value.finalized) return false;
  const isCreator = selectedCampaignInfo.value.creator.toLowerCase() === acc.toLowerCase();
  return isCreator || isExpiredNow.value;
});

const canWithdrawRaised = computed(() => {
  const acc = wallet?.account;
  return selectedCampaignInfo.value && acc && selectedCampaignInfo.value.creator.toLowerCase() === acc.toLowerCase() && selectedCampaignInfo.value.finalized && selectedCampaignInfo.value.success && !selectedCampaignInfo.value.raisedWithdrawn;
});

const canWithdrawDeposit = computed(() => {
  const acc = wallet?.account;
  return selectedCampaignInfo.value && acc && selectedCampaignInfo.value.creator.toLowerCase() === acc.toLowerCase() && selectedCampaignInfo.value.finalized && !selectedCampaignInfo.value.depositWithdrawn;
});

const isCreator = computed(() => {
  const acc = wallet?.account;
  return selectedCampaignInfo.value && acc && selectedCampaignInfo.value.creator.toLowerCase() === acc.toLowerCase();
});

// 实时判断是否过期（不依赖合约返回的 isExpired 快照）
const isExpiredNow = computed(() => {
  if (!selectedCampaignInfo.value) return false;
  return nowTs.value >= selectedCampaignInfo.value.deadline;
});

const hasParticipated = computed(() => {
  return selectedUserInfo.value && parseFloat(selectedUserInfo.value.ethContributed) > 0;
});

const hasClaimed = computed(() => {
  return selectedCampaignInfo.value?.finalized && selectedCampaignInfo.value?.success
    && selectedUserInfo.value && parseFloat(selectedUserInfo.value.contribution) === 0
    && parseFloat(selectedUserInfo.value.ethContributed) > 0;
});

const hasRefunded = computed(() => {
  return selectedCampaignInfo.value?.finalized && !selectedCampaignInfo.value?.success
    && selectedUserInfo.value && parseFloat(selectedUserInfo.value.ethContributed) === 0;
});

const canSweepTokens = computed(() => {
  const acc = wallet?.account;
  if (!selectedCampaignInfo.value || !acc) return false;
  const deadline = selectedCampaignInfo.value.deadline;
  const now = Math.floor(Date.now() / 1000);
  return selectedCampaignInfo.value.creator.toLowerCase() === acc.toLowerCase()
    && selectedCampaignInfo.value.finalized && selectedCampaignInfo.value.success
    && !selectedCampaignInfo.value.tokensSwept
    && now >= deadline + 90 * 86400;
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
    const info = await wallet.sdk.getCampaignInfo(address);
    selectedCampaignInfo.value = info;
    selectedUserInfo.value = await wallet.sdk.getCampaignUserInfo(address, wallet.account);

    // 过期自动结算：如果已到期但未结算，自动触发 finalize
    if (info.isExpired && !info.finalized) {
      status.value = '⏰ 众筹已到期，正在自动结算...';
      isError.value = false;
      try {
        await wallet.sdk.finalizeCampaign(address, wallet.account);
        // 重新加载结算后的数据
        selectedCampaignInfo.value = await wallet.sdk.getCampaignInfo(address);
        selectedUserInfo.value = await wallet.sdk.getCampaignUserInfo(address, wallet.account);
        status.value = '✅ 众筹已自动结算' + (selectedCampaignInfo.value.success ? '（成功）' : '（失败，已自动退款）');
      } catch (finalizeErr) {
        console.error('自动结算失败', finalizeErr);
        status.value = `⚠️ 自动结算失败: ${finalizeErr.message}，请手动结算`;
        isError.value = true;
      }
    }
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
    const days = Number(createDays.value) || 0;
    const hours = Number(createHours.value) || 0;
    const minutes = Number(createMinutes.value) || 0;
    const durationSec = days * 86400 + hours * 3600 + minutes * 60;
    if (durationSec <= 0) {
      throw new Error('持续时间必须大于 0');
    }
    const deadlineUnix = Math.floor(Date.now() / 1000) + durationSec;
    await wallet.sdk.createCampaign(
      wallet.account,
      String(createTarget.value ?? '0'),
      String(createTotalToken.value ?? '0'),
      String(createRatio.value ?? '0'),
      createName.value,
      createSymbol.value,
      String(createDeposit.value ?? '0'),
      deadlineUnix
    );
    status.value = '✅ Campaign 创建成功';
    createTarget.value = '';
    createTotalToken.value = '';
    createRatio.value = '';
    createName.value = '';
    createSymbol.value = '';
    createDays.value = '';
    createHours.value = '';
    createMinutes.value = '';
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
    const isCreator = selectedCampaignInfo.value.creator.toLowerCase() === wallet.account.toLowerCase();
    if (!isCreator && !isExpiredNow.value) {
      throw new Error('只有创建者或到期后才能结束众筹');
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

async function handleClaimRefund() {
  if (!wallet?.sdk || !selectedCampaign.value || !wallet?.account) return;
  isProcessing.value = true;
  status.value = '⏳ 正在领取退款...';
  isError.value = false;

  try {
    await wallet.sdk.claimRefund(selectedCampaign.value, wallet.account);
    status.value = '✅ 退款领取成功';
    await selectCampaign(selectedCampaign.value);
  } catch (err) {
    console.error('领取退款失败', err);
    status.value = `❌ 领取退款失败: ${err.message}`;
    isError.value = true;
  } finally {
    isProcessing.value = false;
  }
}

async function handleSweepTokens() {
  if (!wallet?.sdk || !selectedCampaign.value || !wallet?.account) return;
  isProcessing.value = true;
  status.value = '⏳ 正在扫回未领取代币...';
  isError.value = false;

  try {
    await wallet.sdk.sweepUnclaimedTokens(selectedCampaign.value, wallet.account);
    status.value = '✅ 代币扫回成功';
    await selectCampaign(selectedCampaign.value);
  } catch (err) {
    console.error('扫回失败', err);
    status.value = `❌ 扫回失败: ${err.message}`;
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
  grid-template-columns: minmax(320px, 360px) minmax(0, 1fr);
  gap: 16px;
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
  gap: 10px;
  margin-bottom: 14px;
}

.field-row {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.field-row label {
  font-size: 0.78rem;
  color: #334155;
  font-weight: 650;
}

.field-row input {
  width: 100%;
  padding: 8px 10px;
  border: 1px solid rgba(148, 163, 184, 0.45);
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.95);
  outline: none;
  font-size: 0.85rem;
  box-sizing: border-box;
  transition: box-shadow 140ms ease, border-color 140ms ease;
}

.field-row input:focus {
  border-color: rgba(59, 130, 246, 0.65);
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.15);
}

/* 持续时间输入 */
.duration-inputs {
  display: flex;
  gap: 8px;
  width: 100%;
}

.dur-field {
  flex: 1;
  display: flex;
  align-items: center;
  border: 1px solid rgba(148, 163, 184, 0.45);
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.95);
  overflow: hidden;
  transition: box-shadow 140ms ease, border-color 140ms ease;
}

.dur-field:focus-within {
  border-color: rgba(59, 130, 246, 0.65);
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.15);
}

.dur-field input {
  flex: 1;
  min-width: 0;
  padding: 8px 4px 8px 8px;
  border: none !important;
  border-radius: 0 !important;
  background: transparent !important;
  box-shadow: none !important;
  font-size: 0.85rem;
  text-align: center;
  outline: none;
}

.dur-unit {
  padding: 8px 8px 8px 2px;
  font-size: 0.75rem;
  color: #64748b;
  font-weight: 600;
  white-space: nowrap;
  flex-shrink: 0;
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

.badge-expired {
  background: rgba(245, 158, 11, 0.1);
  color: #d97706;
}

.text-red {
  color: #dc2626 !important;
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

.user-section.creator-section {
  background: linear-gradient(135deg, rgba(245, 158, 11, 0.06), rgba(217, 119, 6, 0.03));
  border: 1px solid rgba(245, 158, 11, 0.18);
}

.user-section.creator-section h4 {
  color: #92400e;
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

.auto-refund-notice {
  padding: 10px 14px;
  border-radius: 10px;
  background: rgba(245, 158, 11, 0.08);
  border: 1px solid rgba(245, 158, 11, 0.2);
  color: #92400e;
  font-size: 0.85rem;
  font-weight: 600;
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