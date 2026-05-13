<script setup>
import StakingPanel from './components/StakingPanel.vue';
import CrowdfundingPanel from './components/CrowdfundingPanel.vue';
</script>

<template>
  <div id="app" class="app">
    <header class="app-header">
      <div class="app-title">Solidity Demo</div>
      <div class="app-subtitle">Staking Vault & Crowdfunding Factory</div>
    </header>

    <main class="app-grid">
      <StakingPanel />
      <CrowdfundingPanel />
    </main>
  </div>
</template>

<style>
:root {
  --bg0: #0b1220;
  --bg1: #0f1b33;
  --card: rgba(255, 255, 255, 0.92);
  --card2: rgba(255, 255, 255, 0.86);
  --text: #0f172a;
  --muted: #475569;
  --ring: rgba(59, 130, 246, 0.28);
  --shadow: 0 18px 45px rgba(2, 6, 23, 0.35);
  --shadow2: 0 10px 24px rgba(2, 6, 23, 0.22);
}

html, body, #app {
  height: 100%;
}

body {
  margin: 0;
  color: var(--text);
  background:
    radial-gradient(1200px 700px at 12% 10%, rgba(56, 189, 248, 0.25), transparent 55%),
    radial-gradient(900px 600px at 85% 30%, rgba(34, 197, 94, 0.20), transparent 55%),
    linear-gradient(180deg, var(--bg0), var(--bg1));
  font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, "Apple Color Emoji", "Segoe UI Emoji";
}

.app {
  max-width: 1180px;
  margin: 0 auto;
  padding: 28px 18px 56px;
}

.app-header {
  margin-bottom: 18px;
  padding: 18px 18px 0;
}

.app-title {
  color: rgba(255, 255, 255, 0.92);
  font-weight: 750;
  letter-spacing: 0.2px;
  font-size: 1.35rem;
}

.app-subtitle {
  margin-top: 6px;
  color: rgba(226, 232, 240, 0.78);
  font-size: 0.95rem;
}

.app-grid {
  display: grid;
  grid-template-columns: 1fr 1.35fr;
  gap: 18px;
  align-items: start;
}

@media (max-width: 980px) {
  .app-grid {
    grid-template-columns: 1fr;
  }
  .app-header {
    padding: 10px 8px 0;
  }
}
</style>
