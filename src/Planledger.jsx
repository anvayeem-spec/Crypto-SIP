import PassbookStamp from './PassbookStamp'
import { TOKEN_IN, TOKEN_OUT } from '../lib/contract'

function formatDate(timestampSeconds) {
  if (!timestampSeconds) return '—'
  return new Date(Number(timestampSeconds) * 1000).toLocaleDateString('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  })
}

function formatAmount(rawAmount, decimals = 18) {
  if (rawAmount === undefined || rawAmount === null) return '—'
  const value = Number(rawAmount) / 10 ** decimals
  return value.toLocaleString('en-IN', { maximumFractionDigits: 4 })
}

export default function PlanLedger({ plan, onExecute, onWithdraw, onCancel, actionPending }) {
  if (!plan) {
    return (
      <div className="border border-ink/20 rounded-sm p-8 text-center font-body text-ink-faint bg-paper-texture">
        No SIP open yet. Fill in the form to start your first instalment plan.
      </div>
    )
  }

  const progress = plan.totalIntervals > 0 ? Number(plan.executedIntervals) / Number(plan.totalIntervals) : 0
  const isDue = plan.active && Date.now() / 1000 >= Number(plan.nextExecution)
  const availableToWithdraw = BigInt(plan.totalReceived ?? 0) - BigInt(plan.withdrawn ?? 0)

  const rows = Array.from({ length: Number(plan.totalIntervals) }, (_, i) => {
    const entryNo = i + 1
    const executed = entryNo <= Number(plan.executedIntervals)
    return { entryNo, executed }
  })

  return (
    <div className="bg-paper border-[3px] border-ink/80 rounded-sm bg-paper-texture">
      <div className="flex items-center justify-between p-6 border-b-2 border-dashed border-ink/30">
        <div>
          <div className="font-display italic text-xl text-ink">SIP Passbook</div>
          <div className="font-mono text-xs text-ink-faint mt-1">
            {TOKEN_IN.symbol} → {TOKEN_OUT.symbol} · {plan.executedIntervals} of {plan.totalIntervals} instalments
          </div>
        </div>
        <PassbookStamp
          label={plan.active ? (isDue ? 'Due now' : 'Next debit') : 'Completed'}
          dateLabel={plan.active ? formatDate(plan.nextExecution) : '—'}
          tone={plan.active ? (isDue ? 'stamp' : 'ink') : 'gold'}
        />
      </div>

      <div className="px-6 pt-4">
        <div className="w-full h-2 bg-ink/10 rounded-full overflow-hidden">
          <div
            className="h-full bg-ink transition-all duration-500"
            style={{ width: `${Math.round(progress * 100)}%` }}
          />
        </div>
      </div>

      <div className="p-6 grid grid-cols-3 gap-4 font-mono text-sm">
        <div>
          <div className="text-ink-faint text-xs uppercase tracking-widest mb-1">Invested</div>
          <div className="text-ink text-lg">
            {formatAmount(plan.totalInvested, TOKEN_IN.decimals)} {TOKEN_IN.symbol}
          </div>
        </div>
        <div>
          <div className="text-ink-faint text-xs uppercase tracking-widest mb-1">Received</div>
          <div className="text-ink text-lg">
            {formatAmount(plan.totalReceived, TOKEN_OUT.decimals)} {TOKEN_OUT.symbol}
          </div>
        </div>
        <div>
          <div className="text-ink-faint text-xs uppercase tracking-widest mb-1">Available</div>
          <div className="text-ink text-lg">
            {formatAmount(availableToWithdraw, TOKEN_OUT.decimals)} {TOKEN_OUT.symbol}
          </div>
        </div>
      </div>

      <div className="px-6 pb-4 max-h-56 overflow-y-auto">
        <table className="w-full font-mono text-sm">
          <thead>
            <tr className="text-left text-ink-faint text-xs uppercase tracking-widest border-b border-ink/20">
              <th className="py-2 font-normal">Entry</th>
              <th className="py-2 font-normal">Status</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.entryNo} className="border-b border-dotted border-ink/15">
                <td className="py-2 text-ink-faint">
                  {String(row.entryNo).padStart(2, '0')}
                </td>
                <td className="py-2">
                  {row.executed ? (
                    <span className="text-ink-soft">Cleared</span>
                  ) : (
                    <span className="text-ink-faint/70">Pending</span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="flex flex-wrap gap-3 p-6 border-t-2 border-dashed border-ink/30">
        <button
          onClick={onExecute}
          disabled={!isDue || actionPending}
          className="font-mono text-xs uppercase tracking-widest bg-ink text-paper px-4 py-2 rounded-sm hover:bg-ink-soft transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
        >
          Execute due instalment
        </button>
        <button
          onClick={onWithdraw}
          disabled={availableToWithdraw <= 0n || actionPending}
          className="font-mono text-xs uppercase tracking-widest border border-ink text-ink px-4 py-2 rounded-sm hover:bg-ink/5 transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
        >
          Withdraw {TOKEN_OUT.symbol}
        </button>
        <button
          onClick={onCancel}
          disabled={!plan.active || actionPending}
          className="font-mono text-xs uppercase tracking-widest border border-stamp text-stamp px-4 py-2 rounded-sm hover:bg-stamp/5 transition-colors disabled:opacity-40 disabled:cursor-not-allowed ml-auto"
        >
          Cancel plan
        </button>
      </div>
    </div>
  )
}
