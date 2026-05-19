import { ref, computed, reactive, onMounted, onUnmounted } from 'vue';
import { createStakingSDK } from '../sdk/index.js';

const HARDHAT_CHAIN_ID = '0x7a69';

export function useWallet() {
  const account = ref(null);
  const sdk = ref(null);
  const isConnecting = ref(false);
  const connectionError = ref('');

  const shortAddress = computed(() =>
    account.value ? `${account.value.slice(0, 6)}...${account.value.slice(-4)}` : ''
  );

  function rebuildSdk() {
    if (window.ethereum) {
      sdk.value = createStakingSDK(window.ethereum);
    } else {
      sdk.value = null;
    }
  }

  async function connectWallet() {
    connectionError.value = '';
    if (!window.ethereum) {
      connectionError.value = '请安装 MetaMask 或支持的以太坊钱包';
      return;
    }
    isConnecting.value = true;
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
              rpcUrls: [`http://${window.location.hostname}:8545`],
            }],
          });
        } else {
          throw err;
        }
      }
      account.value = accounts[0] ?? null;
      rebuildSdk();
    } catch (err) {
      connectionError.value = err?.message || String(err);
      account.value = null;
      sdk.value = null;
    } finally {
      isConnecting.value = false;
    }
  }

  function handleAccountsChanged(accounts) {
    const next = accounts?.[0] ?? null;
    account.value = next;
    if (!next) {
      sdk.value = null;
      return;
    }
    rebuildSdk();
  }

  function handleChainChanged() {
    rebuildSdk();
  }

  onMounted(() => {
    if (window.ethereum?.on) {
      window.ethereum.on('accountsChanged', handleAccountsChanged);
      window.ethereum.on('chainChanged', handleChainChanged);
    }
  });

  onUnmounted(() => {
    if (window.ethereum?.removeListener) {
      window.ethereum.removeListener('accountsChanged', handleAccountsChanged);
      window.ethereum.removeListener('chainChanged', handleChainChanged);
    }
  });

  return reactive({
    account,
    sdk,
    shortAddress,
    isConnecting,
    connectionError,
    connectWallet,
  });
}
