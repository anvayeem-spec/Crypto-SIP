import { useCallback, useEffect, useState } from 'react'
import { Contract, parseUnits } from 'ethers'
import { useWallet } from './lib/useWallet'
import {
  SIP_VAULT_ADDRESS,
  SIP_VAULT_ABI,
  ERC20_ABI,
  TOKEN_IN,
  TOKEN_OUT,
} from './lib/contract'
import WalletConnect from './components/WalletConnect'
import CreatePlanForm from './components/CreatePlanForm'
import PlanLedger from './components/PlanLedger'

export default function App() {
  const { address, provider, connecting, error, connect, disconnect } = useWallet()
  const [plan, setPlan] = useState(null)
  const [planId, setPlanId] = useState(null)
  const [submitting, setSubmitting] = useState(false)
  const [actionPending, setActionPending] = useState(false)
  const [txError, setTxError] = useState(null)

  const getVaultContract = useCallback(
    async (withSigner = false) => {
      if (!provider) return null
      const signerOrProvider = withSigner ? await provider.getSigner() : provider
      return new Contract(SIP_VAULT_ADDRESS, SIP_VAULT_ABI, signerOrProvider)
    },
    [provider]
  )

  const refreshPlan = useCallback(async () => {
    if (!provider || planId === null) return
    try {
      const vault = await getVaultContract(false)
      const result = await vault.getPlan(planId)
      setPlan(result)
    } catch (err) {
      setTxError(err?.reason ?? err?.message ?? 'Could not load plan')
    }
  }, [provider, planId, getVaultContract])

  useEffect(() => {
    refreshPlan()
  }, [refreshPlan])

  const handleCreatePlan = async ({ amount, intervalSeconds, totalIntervals }) => {
    setTxError(null)
    setSubmitting(true)
    try {
      const signer = await provider.getSigner()
      const tokenIn = new Contract(TOKEN_IN.address, ERC20_ABI, signer)
      const vault = await getVaultContract(true)

      const amountPerInterval = parseUnits(amount, TOKEN_IN.decimals)
      const totalAmount = amountPerInterval * BigInt(totalIntervals)

      // approve first, then create — two separate wallet confirmations
      const approveTx = await tokenIn.approve(SIP_VAULT_ADDRESS, totalAmount)
      await approveTx.wait()

      const createTx = await vault.createPlan(
        TOKEN_IN.address,
        TOKEN_OUT.address,
        amountPerInterval,
        intervalSeconds,
        totalIntervals
      )
      const receipt = await createTx.wait()

      // pull the new planId from the PlanCreated event
      const event = receipt.logs
        .map((log) => {
          try {
            return vault.interface.parseLog(log)
          } catch {
            return null
          }
        })
        .find((parsed) => parsed?.name === 'PlanCreated')

      if (event) {
        setPlanId(event.args.planId)
      }
    } catch (err) {
      setTxError(err?.reason ?? err?.message ?? 'Failed to create plan')
    } finally {
      setSubmitting(false)
    }
  }

  const handleExecute = async () => {
    if (planId === null) return
    setTxError(null)
    setActionPending(true)
    try {
      const vault = await getVaultContract(true)
      // NOTE: minAmountOut hardcoded to 0 here for the demo UI — in a real
      // deployment this should be computed from a live quote before calling,
      // exactly the slippage protection the contract enforces.
      const tx = await vault.executeInterval(planId, 0)
      await tx.wait()
      await refreshPlan()
    } catch (err) {
      setTxError(err?.reason ?? err?.message ?? 'Failed to execute instalment')
    } finally {
      setActionPending(false)
    }
  }

  const handleWithdraw = async () => {
    if (planId === null) return
    setTxError(null)
    setActionPending(true)
    try {
      const vault = await getVaultContract(true)
      const tx = await vault.withdraw(planId)
      await tx.wait()
      await refreshPlan()
    } catch (err) {
      setTxError(err?.reason ?? err?.message ?? 'Failed to withdraw')
    } finally {
      setActionPending(false)
    }
  }

  const handleCancel = async () => {
    if (planId === null) return
    setTxError(null)
    setActionPending(true)
    try {
      const vault = await getVaultContract(true)
      const tx = await vault.cancelPlan(planId)
      await tx.wait()
      await refreshPlan()
    } catch (err) {
      setTxError(err?.reason ?? err?.message ?? 'Failed to cancel plan')
    } finally {
      setActionPending(false)
    }
  }

  return (
    <div className="min-h-screen bg-paper bg-paper-texture">
      <div className="max-w-3xl mx-auto px-6 py-12">
        <header className="flex items-start justify-between mb-12">
          <div>
            <h1 className="font-display italic text-4xl text-ink">SIPVault</h1>
            <p className="font-body text-ink-faint mt-1">
              A systematic instalment plan, kept on-chain.
            </p>
          </div>
          <WalletConnect
            address={address}
            connecting={connecting}
            error={error}
            onConnect={connect}
            onDisconnect={disconnect}
          />
        </header>

        {txError && (
          <div className="mb-6 border border-stamp/40 bg-stamp/5 text-stamp text-sm font-mono px-4 py-3 rounded-sm">
            {txError}
          </div>
        )}

        <div className="grid gap-8">
          <CreatePlanForm
            onSubmit={handleCreatePlan}
            submitting={submitting}
            disabled={!address}
          />
          <PlanLedger
            plan={plan}
            onExecute={handleExecute}
            onWithdraw={handleWithdraw}
            onCancel={handleCancel}
            actionPending={actionPending}
          />
        </div>

        <footer className="mt-16 text-center font-mono text-xs text-ink-faint">
          Contract: {SIP_VAULT_ADDRESS.slice(0, 10)}… · Built with Foundry + ethers.js
        </footer>
      </div>
    </div>
  )
}
