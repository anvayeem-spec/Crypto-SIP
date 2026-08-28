import { useState } from 'react'
import { TOKEN_IN, TOKEN_OUT } from '../lib/contract'

const INTERVAL_OPTIONS = [
  { label: 'Weekly', seconds: 7 * 24 * 60 * 60 },
  { label: 'Bi-weekly', seconds: 14 * 24 * 60 * 60 },
  { label: 'Monthly', seconds: 30 * 24 * 60 * 60 },
]

export default function CreatePlanForm({ onSubmit, submitting, disabled }) {
  const [amount, setAmount] = useState('')
  const [intervalSeconds, setIntervalSeconds] = useState(INTERVAL_OPTIONS[0].seconds)
  const [totalIntervals, setTotalIntervals] = useState('12')

  const handleSubmit = (e) => {
    e.preventDefault()
    if (!amount || Number(amount) <= 0) return
    onSubmit({
      amount,
      intervalSeconds,
      totalIntervals: Number(totalIntervals),
    })
  }

  const totalCommitment =
    amount && totalIntervals ? (Number(amount) * Number(totalIntervals)).toLocaleString() : '—'

  return (
    <form
      onSubmit={handleSubmit}
      className="bg-paper border-[3px] border-ink/80 rounded-sm p-8 bg-paper-texture relative"
    >
      <div className="absolute -top-3 left-8 bg-paper px-3 font-display text-sm italic text-ink-soft">
        Open a new entry
      </div>

      <div className="grid gap-6 mt-2">
        <div>
          <label className="block font-mono text-xs uppercase tracking-widest text-ink-faint mb-2">
            Amount per instalment ({TOKEN_IN.symbol})
          </label>
          <input
            type="number"
            min="0"
            step="any"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="500"
            className="w-full bg-transparent border-b-2 border-ink/30 focus:border-ink outline-none font-mono text-2xl py-2 transition-colors"
            required
          />
        </div>

        <div className="grid grid-cols-2 gap-6">
          <div>
            <label className="block font-mono text-xs uppercase tracking-widest text-ink-faint mb-2">
              Frequency
            </label>
            <select
              value={intervalSeconds}
              onChange={(e) => setIntervalSeconds(Number(e.target.value))}
              className="w-full bg-transparent border-b-2 border-ink/30 focus:border-ink outline-none font-body py-2 transition-colors"
            >
              {INTERVAL_OPTIONS.map((opt) => (
                <option key={opt.seconds} value={opt.seconds}>
                  {opt.label}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block font-mono text-xs uppercase tracking-widest text-ink-faint mb-2">
              Number of instalments
            </label>
            <input
              type="number"
              min="1"
              value={totalIntervals}
              onChange={(e) => setTotalIntervals(e.target.value)}
              className="w-full bg-transparent border-b-2 border-ink/30 focus:border-ink outline-none font-mono py-2 transition-colors"
              required
            />
          </div>
        </div>

        <div className="flex items-baseline justify-between border-t border-dotted border-ink/40 pt-4">
          <span className="font-body text-sm text-ink-faint">Total commitment</span>
          <span className="font-mono text-lg text-ink">
            {totalCommitment} {TOKEN_IN.symbol} → {TOKEN_OUT.symbol}
          </span>
        </div>

        <button
          type="submit"
          disabled={disabled || submitting}
          className="mt-2 bg-stamp text-paper font-mono uppercase tracking-widest text-sm py-3 rounded-sm hover:bg-stamp-soft transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {submitting ? 'Opening entry…' : 'Open SIP'}
        </button>

        {disabled && (
          <p className="text-xs text-ink-faint font-body text-center -mt-2">
            Connect your wallet to open a SIP.
          </p>
        )}
      </div>
    </form>
  )
}
