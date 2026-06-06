/** Claude 取込用プロンプト（プレースホルダ置換後にコピー用テキストとして使う）。本文は DB（user_preferences）に保存。 */

/** 旧 localStorage からの一回だけの移行用 */
const LEGACY_IMPORT_PROMPT_STORAGE_KEY = "solarc.importClaudePromptTemplate"

/** 置換用（カスタム本文に必ず含めること） */
export const IMPORT_PROMPT_PLACEHOLDERS = {
  CATALOG: "{{CATALOG}}",
  PAYMENT_METHOD_NAME: "{{PAYMENT_METHOD_NAME}}",
  EXAMPLE_MINOR_ID: "{{EXAMPLE_MINOR_ID}}",
  /** 取込対象の利用月を「YYYY年MM月」で差し込む（内部の基準は YYYY-MM） */
  MONTH: "{{month}}",
} as const

const backtick = "`"

export const DEFAULT_IMPORT_PROMPT_TEMPLATE = [
  "次の支払明細を、JSONの配列だけにしてください（説明・" + backtick + backtick + backtick + "・コメントは禁止）。",
  "",
  "1行＝単発支出1件。支払方法はすべて「{{PAYMENT_METHOD_NAME}}」固定（翌月引き落としのクレカ扱い）なので JSON には含めない。",
  "キーは次のとおり:",
  '- "month": "YYYY-MM" または "YYYY年MM月"（必須。**カード利用があった月**。例の {{month}} と同じ表記に揃える。家計簿の実績は翌暦月に計上される）',
  '- "minor_category_id": 数値（必須。下の一覧の id のいずれか。明細の内容に最も近い小カテゴリを選ぶ）',
  '- "amount": 数値（必須。円、0以上。支出はプラスの数で）',
  '- "memo": 文字列（任意。短いメモ）',
  "",
  "利用可能な小カテゴリ（支出）:",
  "{{CATALOG}}",
  "",
  "例:",
  '[{"month":"{{month}}","minor_category_id":{{EXAMPLE_MINOR_ID}},"amount":3500,"memo":"コンビニ"}]',
  "",
  "不明な行は出力しない。",
  "",
  "（明細をここに貼る）",
].join("\n")

function formatImportMonthForPrompt(isoYyyyMm: string): string {
  const compact = String(isoYyyyMm).trim().slice(0, 7)
  if (!/^\d{4}-\d{2}$/.test(compact)) return String(isoYyyyMm).trim()
  const [y, mo] = compact.split("-")
  return `${y}年${mo}月`
}

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

/** 旧ブラウザ保存から移行（存在したら読んでキー削除） */
export function takeLegacyImportPromptFromLocalStorage(): string | null {
  try {
    const raw = localStorage.getItem(LEGACY_IMPORT_PROMPT_STORAGE_KEY)
    if (raw == null || raw.trim() === "") return null
    localStorage.removeItem(LEGACY_IMPORT_PROMPT_STORAGE_KEY)
    return raw
  } catch {
    return null
  }
}

export function substituteImportPromptPlaceholders(
  template: string,
  params: { catalog: string; paymentMethodName: string; exampleMinorId: number; month: string },
): string {
  return template
    .replaceAll(IMPORT_PROMPT_PLACEHOLDERS.CATALOG, params.catalog)
    .replaceAll(IMPORT_PROMPT_PLACEHOLDERS.PAYMENT_METHOD_NAME, params.paymentMethodName)
    .replaceAll(IMPORT_PROMPT_PLACEHOLDERS.EXAMPLE_MINOR_ID, String(params.exampleMinorId))
    .replaceAll(IMPORT_PROMPT_PLACEHOLDERS.MONTH, formatImportMonthForPrompt(params.month))
}

export function buildImportClaudePrompt(params: {
  catalog: string
  paymentMethodName: string
  exampleMinorId: number
  /** 対象月 YYYY-MM（`{{month}}` には「YYYY年MM月」で差し込む） */
  month: string
  savedTemplate: string | null | undefined
}): string {
  const custom = params.savedTemplate
  const base =
    custom != null && String(custom).trim() !== "" ? String(custom).trim() : DEFAULT_IMPORT_PROMPT_TEMPLATE
  return substituteImportPromptPlaceholders(base, {
    catalog: params.catalog,
    paymentMethodName: params.paymentMethodName,
    exampleMinorId: params.exampleMinorId,
    month: params.month,
  })
}

export function validateImportPromptTemplate(template: string): string | null {
  const t = template.trim()
  if (t === "") return "プロンプトが空です"
  for (const ph of Object.values(IMPORT_PROMPT_PLACEHOLDERS)) {
    if (!t.includes(ph)) {
      return `プロンプトに ${ph} を含めてください（カテゴリ一覧・支払方法名・例の id・対象月 を差し込むために必要です）`
    }
  }
  return null
}
