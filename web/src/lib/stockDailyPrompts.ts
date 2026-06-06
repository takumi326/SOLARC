import type { UserPreferences } from "./api.ts"

export function stockDailyPromptsFromPrefs(p: UserPreferences): {
  hypothesis: string
  result: string
  sector: string
} {
  return {
    hypothesis: (p.stock_daily_hypothesis_prompt ?? "").trimEnd(),
    result: (p.stock_daily_result_prompt ?? "").trimEnd(),
    sector: (p.stock_daily_sector_prompt ?? "").trimEnd(),
  }
}

/** `YYYY-MM-DD` → `YYYY年MM月DD日` */
export function formatRecordDateJp(isoDate: string): string {
  const parts = isoDate.split("-")
  if (parts.length !== 3) return isoDate
  const [y, mo, da] = parts
  const yn = Number(y)
  const mon = Number(mo)
  const dayn = Number(da)
  if (!Number.isFinite(yn) || !Number.isFinite(mon) || !Number.isFinite(dayn)) return isoDate
  return `${yn}年${String(mon).padStart(2, "0")}月${String(dayn).padStart(2, "0")}日`
}

/** `YYYY-MM-DD` の暦日前日（ローカル暦） */
export function previousCalendarDayIso(isoDate: string): string {
  const parts = isoDate.split("-")
  if (parts.length !== 3) return isoDate
  const y = Number(parts[0])
  const m = Number(parts[1])
  const d = Number(parts[2])
  if (!Number.isFinite(y) || !Number.isFinite(m) || !Number.isFinite(d)) return isoDate
  const dt = new Date(y, m - 1, d)
  dt.setDate(dt.getDate() - 1)
  const yy = dt.getFullYear()
  const mm = String(dt.getMonth() + 1).padStart(2, "0")
  const dd = String(dt.getDate()).padStart(2, "0")
  return `${yy}-${mm}-${dd}`
}

/** `recorded_on` / `date` などから比較用の暦日キー `YYYY-MM-DD` を得る */
export function normalizeCalendarDateKey(value: string): string {
  const t = String(value ?? "").trim()
  const m = /^(\d{4}-\d{2}-\d{2})/.exec(t)
  if (m) return m[1]
  const d = new Date(t)
  if (Number.isNaN(d.getTime())) return t.slice(0, 10)
  const y = d.getFullYear()
  const mo = String(d.getMonth() + 1).padStart(2, "0")
  const da = String(d.getDate()).padStart(2, "0")
  return `${y}-${mo}-${da}`
}

/** 結果プロンプト用: まず `focusIsoDate` の値、前後空白のみなら暦の前日の行 */
function dailyNoteFieldWithPrevDayFallback<TRow extends { date: string }>(
  rows: readonly TRow[],
  focusIsoDate: string,
  pick: (row: TRow) => string | null | undefined,
): string {
  const focus = normalizeCalendarDateKey(focusIsoDate)
  const map = new Map<string, string>()
  for (const r of rows) {
    map.set(normalizeCalendarDateKey(r.date), String(pick(r) ?? ""))
  }
  const primary = map.get(focus) ?? ""
  if (String(primary).trim()) return primary
  const prev = previousCalendarDayIso(focus)
  return map.get(prev) ?? ""
}

/**
 * 毎日の記録の行から結果プロンプト用の仮説本文を得る。
 * まず `focusIsoDate` の行の仮説、前後空白のみなら暦の前日の行の仮説。
 */
export function hypothesisForResultPromptFromRows(
  rows: readonly { date: string; hypothesis?: string | null }[],
  focusIsoDate: string,
): string {
  return dailyNoteFieldWithPrevDayFallback(rows, focusIsoDate, (r) => r.hypothesis)
}

/**
 * 毎日の記録の行から結果プロンプト用の結果本文を得る。
 * まず `focusIsoDate` の行の結果、前後空白のみなら暦の前日の行の結果。
 */
export function resultForResultPromptFromRows(
  rows: readonly { date: string; result?: string | null }[],
  focusIsoDate: string,
): string {
  return dailyNoteFieldWithPrevDayFallback(rows, focusIsoDate, (r) => r.result)
}

/**
 * 結果プロンプトの `{{hypothesis}}` 用（API 行の `recorded_on` 想定）。
 * まず `focusIsoDate` の仮説、空ならその前日。
 */
export function hypothesisBodyForResultPromptCopy(
  notes: readonly { recorded_on: string; hypothesis?: string | null }[],
  focusIsoDate: string,
): string {
  return hypothesisForResultPromptFromRows(
    notes.map((n) => ({ date: n.recorded_on, hypothesis: n.hypothesis })),
    focusIsoDate,
  )
}

/** 結果・セクター調べプロンプトコピーは前日フォールバック、仮説コピーはコピー実行日のみ */
export function usesPrevDayFallbackForStockPromptCopy(kind: "hypothesis" | "result" | "sector"): boolean {
  return kind === "result" || kind === "sector"
}

/** コピー実行日の記録の結果本文（その日の行が無ければ空） */
export function resultBodyFromRows(
  rows: readonly { date: string; result?: string | null }[],
  focusIsoDate: string,
): string {
  const focus = normalizeCalendarDateKey(focusIsoDate)
  const map = new Map<string, string>()
  for (const r of rows) {
    map.set(normalizeCalendarDateKey(r.date), String(r.result ?? ""))
  }
  return map.get(focus) ?? ""
}

/** 株プロンプト用。コピー時に日付・仮説・結果のプレースホルダを置換する */
export function applyStockPromptPlaceholders(
  text: string,
  recordedOnIso: string,
  hypothesisBody: string,
  resultBody = "",
): string {
  const jp = formatRecordDateJp(recordedOnIso)
  return text
    .replace(/\{\{\s*date_iso\s*\}\}/gi, recordedOnIso)
    .replace(/\{\{\s*date\s*\}\}/gi, jp)
    .replace(/\{\{\s*記録日\s*\}\}/g, jp)
    .replace(/\{\{\s*hypothesis\s*\}\}/gi, () => hypothesisBody)
    .replace(/\{\{\s*result\s*\}\}/gi, () => resultBody)
}
