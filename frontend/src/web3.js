import { ethers } from "ethers";
import { STAKING_VAULT_ADDR, STAKING_VAULT_ABI } from './sdk/contract.js';

export async function getContract() {
  if (!window.ethereum) {
    throw new Error("MetaMask not installed");
  }

  const provider = new ethers.providers.Web3Provider(window.ethereum);
  const signer = provider.getSigner();

  return new ethers.Contract(STAKING_VAULT_ADDR, STAKING_VAULT_ABI, signer);
}