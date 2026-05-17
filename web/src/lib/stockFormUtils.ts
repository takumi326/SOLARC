/** API の date / datetime を input[type=date] 用に */
export function toDateInputValue(v: string | null | undefined): string {
  if (!v) return ""
  const s = v.trim()
  if (/^\d{4}-\d{2}-\d{2}/.test(s)) return s.slice(0, 10)
  return s
}

export function emptyToNull(s: string): string | null {
  const t = s.trim()
  return t === "" ? null : t
}

export function parseOptionalInt(s: string): number | null {
  const t = s.trim()
  if (t === "") return null
  const n = Number(t)
  return Number.isFinite(n) ? n : null
}
