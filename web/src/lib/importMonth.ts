/** 取込 JSON の `month`（`YYYY-MM` または `YYYY年MM月`）→ `YYYY-MM`。解釈不能なら null */
export function parseImportMonthField(raw: unknown): string | null {
  const s = String(raw ?? "").trim()
  if (/^\d{4}-\d{2}/.test(s)) return s.slice(0, 7)
  const m = s.match(/^(\d{4})年(\d{1,2})月/)
  if (m) {
    const y = m[1]
    const mo = String(Number.parseInt(m[2], 10)).padStart(2, "0")
    return `${y}-${mo}`
  }
  return null
}
