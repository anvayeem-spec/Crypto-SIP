function shortenAddress(addr) {
  if (!addr) return ''
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`
}

export default function WalletConnect({ address, connecting, error, onConnect, onDisconnect }) {
  return (
    <div className="flex flex-col items-end gap-1">
      {address ? (
        <button
          onClick={onDisconnect}
          className="font-mono text-sm border border-ink/40 px-4 py-2 rounded-sm hover:bg-ink/5 transition-colors"
        >
          {shortenAddress(address)} · Disconnect
        </button>
      ) : (
        <button
          onClick={onConnect}
          disabled={connecting}
          className="font-mono text-sm bg-ink text-paper px-4 py-2 rounded-sm hover:bg-ink-soft transition-colors disabled:opacity-50"
        >
          {connecting ? 'Connecting…' : 'Connect wallet'}
        </button>
      )}
      {error && <span className="text-xs text-stamp font-body">{error}</span>}
    </div>
  )
}
