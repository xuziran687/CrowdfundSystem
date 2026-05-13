<script setup>
import { provide } from 'vue';
import { useWallet } from './composables/useWallet.js';
import StakingPanel from './components/StakingPanel.vue';
import CrowdfundingPanel from './components/CrowdfundingPanel.vue';

const wallet = useWallet();
provide('wallet', wallet);
</script>

<template>
  <div id="app" class="app">
    <header class="app-topbar">
      <div class="brand">
        <div class="app-title">Solidity Demo</div>
        <div class="app-subtitle">金库质押与众筹工厂 · 本地 Hardhat</div>
      </div>
      <div class="wallet-actions">
        <template v-if="wallet.account">
          <span class="chain-tag">Chain 31337</span>
          <span class="addr-pill">{{ wallet.shortAddress }}</span>
        </template>
        <button
          v-else
          type="button"
          class="btn-connect"
          :disabled="wallet.isConnecting"
          @click="wallet.connectWallet"
        >
          {{ wallet.isConnecting ? '连接中…' : '连接钱包' }}
        </button>
        <p v-if="wallet.connectionError" class="wallet-error">{{ wallet.connectionError }}</p>
      </div>
    </header>

    <div v-if="!wallet.account" class="hero-cta">
      <p class="hero-text">连接钱包后即可在同一页面使用质押金库与众筹工厂。</p>
      <button
        type="button"
        class="btn-connect btn-connect-lg"
        :disabled="wallet.isConnecting"
        @click="wallet.connectWallet"
      >
        {{ wallet.isConnecting ? '连接中…' : '连接钱包' }}
      </button>
      <p v-if="wallet.connectionError" class="wallet-error hero-err">{{ wallet.connectionError }}</p>
    </div>

    <main v-else class="app-main">
      <div class="dashboard">
        <div class="dashboard-grid">
          <section class="dash-section staking-section">
            <header class="section-head">
              <span class="eyebrow">Vault</span>
              <h2 class="section-title">质押金库</h2>
              <p class="section-desc">质押 ETH、累积 R；众筹认购时可抵扣</p>
            </header>
            <StakingPanel />
          </section>

          <div class="dash-divider" aria-hidden="true" />

          <section class="dash-section crowd-section">
            <header class="section-head">
              <span class="eyebrow">Factory</span>
              <h2 class="section-title">众筹工厂</h2>
              <p class="section-desc">创建 Campaign、认购、Finalize 与 Claim / 退款</p>
            </header>
            <CrowdfundingPanel />
          </section>
        </div>
      </div>
    </main>
  </div>
</template>

<style>
:root {
  --bg0: #0b1220;
  --bg1: #0f1b33;
  --text: #0f172a;
  --muted: #64748b;
  --surface: rgba(255, 255, 255, 0.94);
  --surface-soft: rgba(248, 250, 252, 0.96);
  --border: rgba(226, 232, 240, 0.95);
}

html,
body,
#app {
  min-height: 100%;
}

body {
  margin: 0;
  color: var(--text);
  background:
    radial-gradient(1200px 700px at 12% 10%, rgba(56, 189, 248, 0.22), transparent 55%),
    radial-gradient(900px 600px at 88% 25%, rgba(34, 197, 94, 0.16), transparent 50%),
    linear-gradient(180deg, var(--bg0), var(--bg1));
  font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, "Apple Color Emoji",
    "Segoe UI Emoji";
}

.app {
  max-width: 1240px;
  margin: 0 auto;
  padding: 20px 18px 48px;
}

.app-topbar {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
  padding: 8px 4px 20px;
  flex-wrap: wrap;
}

.brand .app-title {
  color: rgba(255, 255, 255, 0.94);
  font-weight: 750;
  font-size: 1.35rem;
  letter-spacing: 0.02em;
}

.brand .app-subtitle {
  margin-top: 6px;
  color: rgba(226, 232, 240, 0.78);
  font-size: 0.9rem;
}

.wallet-actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: flex-end;
  gap: 10px;
  position: relative;
}

.chain-tag {
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: rgba(226, 232, 240, 0.9);
  border: 1px solid rgba(148, 163, 184, 0.45);
  padding: 6px 10px;
  border-radius: 999px;
  background: rgba(15, 23, 42, 0.35);
}

.addr-pill {
  font-family: ui-monospace, monospace;
  font-size: 0.85rem;
  color: #0f172a;
  background: rgba(255, 255, 255, 0.92);
  border: 1px solid rgba(226, 232, 240, 0.9);
  padding: 8px 14px;
  border-radius: 999px;
  font-weight: 600;
}

.btn-connect {
  border: none;
  border-radius: 12px;
  padding: 10px 20px;
  font-weight: 750;
  font-size: 0.95rem;
  cursor: pointer;
  color: #fff;
  background: linear-gradient(180deg, #16a34a, #15803d);
  box-shadow: 0 10px 24px rgba(2, 6, 23, 0.25);
  transition: transform 0.12s ease, filter 0.12s ease, opacity 0.12s ease;
}

.btn-connect:hover:not(:disabled) {
  transform: translateY(-1px);
  filter: brightness(1.03);
}

.btn-connect:disabled {
  opacity: 0.65;
  cursor: not-allowed;
}

.btn-connect-lg {
  padding: 14px 28px;
  font-size: 1rem;
}

.wallet-error {
  width: 100%;
  margin: 0;
  font-size: 0.82rem;
  color: #fecaca;
}

.hero-cta {
  text-align: center;
  padding: 48px 20px 56px;
  max-width: 420px;
  margin: 0 auto;
}

.hero-text {
  color: rgba(226, 232, 240, 0.88);
  font-size: 1.05rem;
  line-height: 1.6;
  margin: 0 0 22px;
}

.hero-err {
  margin-top: 14px;
}

.app-main {
  margin-top: 4px;
}

.dashboard {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 20px;
  box-shadow: 0 24px 50px rgba(2, 6, 23, 0.28);
  backdrop-filter: blur(12px);
  padding: 22px 20px 26px;
}

.dashboard-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto minmax(0, 1.5fr);
  gap: 0 20px;
  align-items: start;
}

.dash-divider {
  width: 1px;
  min-height: 120px;
  background: linear-gradient(180deg, transparent, rgba(148, 163, 184, 0.45), transparent);
  justify-self: center;
}

.dash-section {
  min-width: 0;
}

.section-head {
  margin-bottom: 16px;
  padding-bottom: 14px;
  border-bottom: 1px solid rgba(226, 232, 240, 0.95);
}

.eyebrow {
  display: inline-block;
  font-size: 0.68rem;
  font-weight: 800;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: #64748b;
  margin-bottom: 6px;
}

.section-title {
  margin: 0 0 6px;
  font-size: 1.2rem;
  font-weight: 750;
  color: #0f172a;
  letter-spacing: 0.01em;
}

.section-desc {
  margin: 0;
  font-size: 0.88rem;
  color: var(--muted);
  line-height: 1.45;
}

@media (max-width: 1000px) {
  .dashboard-grid {
    grid-template-columns: 1fr;
    gap: 20px 0;
  }

  .dash-divider {
    display: none;
  }

  .crowd-section .section-head {
    border-top: 1px solid rgba(226, 232, 240, 0.95);
    padding-top: 18px;
    margin-top: 4px;
    border-bottom: none;
    padding-bottom: 0;
  }
}
</style>
