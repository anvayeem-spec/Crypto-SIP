export default function PassbookStamp({ label, dateLabel, tone = 'stamp' }) {
  const toneClasses =
    tone === 'gold'
      ? 'border-gold text-gold'
      : tone === 'ink'
      ? 'border-ink text-ink'
      : 'border-stamp text-stamp'

  return (
    <div
      className={`stamp-rotate inline-flex flex-col items-center justify-center border-[3px] ${toneClasses} rounded-full w-28 h-28 select-none`}
      style={{ borderStyle: 'double' }}
      aria-label={`${label}: ${dateLabel}`}
    >
      <span className="font-mono text-[10px] tracking-[0.2em] uppercase leading-none">
        {label}
      </span>
      <span className="font-mono text-sm font-semibold leading-tight mt-1 text-center px-2">
        {dateLabel}
      </span>
    </div>
  )
}
