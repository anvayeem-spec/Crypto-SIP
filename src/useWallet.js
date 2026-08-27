import { useCallback, useEffect, useState } from 'react'
import { BrowserProvider } from 'ethers'

export function useWallet() {
  const [address, setAddress] = useState(null)
  const [provider, setProvider] = useState(null)
  const [chainId, setChainId] = useState(null)
  const [connecting, setConnecting] = useState(false)
  const [error, setError] = useState(null)

  const connect = useCallback(async () => {
    if (!window.ethereum) {
      setError('No wallet found. Install MetaMask to continue.')
      return
    }
    setConnecting(true)
    setError(null)
    try {
      const browserProvider = new BrowserProvider(window.ethereum)
      const accounts = await browserProvider.send('eth_requestAccounts', [])
      const network = await browserProvider.getNetwork()
      setProvider(browserProvider)
      setAddress(accounts[0])
      setChainId(network.chainId)
    } catch (err) {
      setError(err?.message ?? 'Wallet connection failed')
    } finally {
      setConnecting(false)
    }
  }, [])

  const disconnect = useCallback(() => {
    setAddress(null)
    setProvider(null)
    setChainId(null)
  }, [])

  useEffect(() => {
    if (!window.ethereum) return
    const handleAccountsChanged = (accounts) => {
      if (accounts.length === 0) {
        disconnect()
      } else {
        setAddress(accounts[0])
      }
    }
    const handleChainChanged = () => {
      window.location.reload()
    }
    window.ethereum.on?.('accountsChanged', handleAccountsChanged)
    window.ethereum.on?.('chainChanged', handleChainChanged)
    return () => {
      window.ethereum.removeListener?.('accountsChanged', handleAccountsChanged)
      window.ethereum.removeListener?.('chainChanged', handleChainChanged)
    }
  }, [disconnect])

  return { address, provider, chainId, connecting, error, connect, disconnect }
}
