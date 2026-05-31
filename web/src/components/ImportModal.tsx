import { useCallback, useEffect, useMemo, useState } from "react"
import { Link } from "react-router-dom"
import { Modal } from "./Modal.tsx"
import { api, type ExpenseMaster, type MinorCategory } from "../lib/api.ts"
import { apiErrorMessage } from "../lib/errors.ts"
import { sortMinorCategories } from "../lib/categorySort.ts"
import { buildImportClaudePrompt, parseImportMonthField } from "../lib/importPromptSettings.ts"
import { useFetch } from "../lib/useFetch.ts"

const FIXED_PAYMENT_METHOD_NAME = "Amazonカード"

const actionButtonClass =
  "inline-flex h-9 w-full shrink-0 items-center justify-center rounded-lg border border-slate-300 bg-white px-2 text-xs font-medium text-slate-800 hover:bg-slate-50 sm:h-auto sm:w-auto sm:px-3 sm:py-1.5 sm:text-sm"

const externalLinkButtonClass =
  "inline-flex h-9 w-full shrink-0 items-center justify-center rounded-lg border border-indigo-200 bg-white px-2 text-xs font-medium text-indigo-700 hover:bg-indigo-50 sm:h-auto sm:w-auto sm:px-3 sm:py-1.5 sm:text-sm"

const CLAUDE_NEW_URL = "https://claude.ai/new"

type Props = {
  onClose: () => void
  onImported: () => void
}

/** Claude 向け: minor_category_id + month + amount。支払は Amazonカード 固定（JSON に含めない）。month は利用月で、翌月クレカとして翌暦月に台帳計上 */
type ImportRow = {
  month?: string
  payment_date?: string
  minor_category_id?: number
  /** 後方互換: 旧プロンプトの文字列カテゴリ */
  category?: string
  amount: number
  payment?: string
  memo?: string
}

type PendingImportRow = {
  lineNumber: number
  monthDate: string
  monthLabel: string
  categoryPath: string
  amount: number
  memo: string | null
  minor: MinorCategory
}

type ExistingExpenseRow = {
  id: number
  monthLabel: string
  categoryPath: string
  amount: number
  memo: string | null
  minorCategoryId: number
  duplicateWithPending: boolean
}

function accrualMonthFirstFromApi(m: string): string {
  const s = String(m).trim()
  if (/^\d{4}-\d{2}-\d{2}/.test(s)) return s.slice(0, 10)
  if (/^\d{4}-\d{2}$/.test(s)) return `${s}-01`
  const d = new Date(s)
  if (!Number.isNaN(d.getTime())) {
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-01`
  }
  return s
}

/** 同期対象月（利用月）にこの支出マスタが載るか（API の target_expenses と同趣旨） */
function expenseAppliesToAccrualMonth(e: ExpenseMaster, accrualMonthFirst: string): boolean {
  const start = accrualMonthFirstFromApi(e.start_month)
  const end = e.end_month ? accrualMonthFirstFromApi(e.end_month) : null
  if (accrualMonthFirst < start) return false
  if (end != null && accrualMonthFirst > end) return false
  if (e.expense_type === "one_time") {
    return accrualMonthFirst === start
  }
  if (e.recurring_cycle === "monthly") {
    return true
  }
  if (e.recurring_cycle === "yearly") {
    const monthNum = Number(accrualMonthFirst.slice(5, 7))
    return (e.renewal_month ?? 0) === monthNum
  }
  return false
}

function minMonthLabel(rows: PendingImportRow[]): string {
  return rows.reduce((min, r) => (r.monthLabel < min ? r.monthLabel : min), rows[0].monthLabel)
}

function buildExistingRows(
  expenses: ExpenseMaster[],
  minors: MinorCategory[],
  compareMonthInput: string,
  pendingRowsForDuplicate: PendingImportRow[],
): ExistingExpenseRow[] {
  const monthFirst = `${compareMonthInput}-01`
  const filtered = expenses.filter(
    (e) => e.expense_type === "one_time" && expenseAppliesToAccrualMonth(e, monthFirst),
  )
  const mapped = filtered.map((e) => {
    const minor = minors.find((m) => m.id === e.minor_category_id)
    const categoryPath = minor
      ? `${minor.major_category.name} / ${minor.name}`
      : `小カテゴリ id:${e.minor_category_id}`
    const amount = Math.round(Number(e.amount))
    const monthLabel = accrualMonthFirstFromApi(e.start_month).slice(0, 7)
    const memoRaw = e.memo != null ? String(e.memo).trim() : ""
    const memo = memoRaw === "" ? null : memoRaw
    const duplicateWithPending = pendingRowsForDuplicate.some(
      (pr) => pr.monthLabel === compareMonthInput && pr.minor.id === e.minor_category_id && pr.amount === amount,
    )
    return {
      id: e.id,
      monthLabel,
      categoryPath,
      amount,
      memo,
      minorCategoryId: e.minor_category_id,
      duplicateWithPending,
    }
  })
  mapped.sort((a, b) => {
    const dup = Number(b.duplicateWithPending) - Number(a.duplicateWithPending)
    if (dup !== 0) return dup
    const cat = a.categoryPath.localeCompare(b.categoryPath, "ja")
    if (cat !== 0) return cat
    if (a.amount !== b.amount) return a.amount - b.amount
    return a.id - b.id
  })
  return mapped
}

function ImportPendingTable({
  title,
  rows,
  selectedLineNumbers,
  onToggleLine,
  onSelectAll,
  onSelectNone,
}: {
  title: string
  rows: { key: number; lineNumber: number; month: string; category: string; amount: number; memo: string | null; warn: boolean }[]
  selectedLineNumbers: ReadonlySet<number>
  onToggleLine: (lineNumber: number, checked: boolean) => void
  onSelectAll: () => void
  onSelectNone: () => void
}) {
  return (
    <div className="flex min-h-0 flex-1 flex-col rounded-lg border border-slate-200">
      <div className="flex shrink-0 flex-wrap items-center justify-between gap-2 border-b border-slate-100 bg-slate-50 px-3 py-2">
        <h4 className="text-sm font-medium text-slate-800">{title}</h4>
        <div className="flex gap-2 text-xs">
          <button type="button" className="font-medium text-indigo-600 hover:text-indigo-500" onClick={onSelectAll}>
            すべて選択
          </button>
          <span className="text-slate-300">|</span>
          <button type="button" className="font-medium text-slate-600 hover:text-slate-800" onClick={onSelectNone}>
            すべて外す
          </button>
        </div>
      </div>
      <div className="min-h-0 max-h-72 flex-1 overflow-auto">
        <table className="min-w-full divide-y divide-slate-200 text-sm">
          <thead className="sticky top-0 z-1 bg-slate-50 text-left text-xs text-slate-500">
            <tr>
              <th className="w-10 px-2 py-2" aria-label="取り込む" />
              <th className="px-3 py-2">月</th>
              <th className="px-3 py-2">カテゴリ</th>
              <th className="px-3 py-2 text-right">金額</th>
              <th className="px-3 py-2">メモ</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {rows.length === 0 ? (
              <tr>
                <td colSpan={5} className="px-3 py-4 text-center text-xs text-slate-500">
                  該当する行がありません
                </td>
              </tr>
            ) : (
              rows.map((r) => (
                <tr key={r.key} className={r.warn ? "bg-amber-50" : undefined}>
                  <td className="px-2 py-2 align-middle">
                    <input
                      type="checkbox"
                      className="h-4 w-4 rounded border-slate-300 text-indigo-600 focus:ring-indigo-500"
                      checked={selectedLineNumbers.has(r.lineNumber)}
                      onChange={(e) => onToggleLine(r.lineNumber, e.target.checked)}
                      aria-label={`行${r.lineNumber}を取り込む`}
                    />
                  </td>
                  <td className="px-3 py-2 whitespace-nowrap">{r.month}</td>
                  <td className="px-3 py-2 text-slate-800">{r.category}</td>
                  <td className="px-3 py-2 text-right font-medium">¥{r.amount.toLocaleString("ja-JP")}</td>
                  <td className="max-w-48 truncate px-3 py-2 text-slate-600" title={r.memo ?? undefined}>
                    {r.memo ?? "—"}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}

function ImportPreviewTable({
  title,
  rows,
}: {
  title: string
  rows: { key: string | number; month: string; category: string; amount: number; memo: string | null; warn: boolean }[]
}) {
  return (
    <div className="flex min-h-0 flex-1 flex-col rounded-lg border border-slate-200">
      <h4 className="shrink-0 border-b border-slate-100 bg-slate-50 px-3 py-2 text-sm font-medium text-slate-800">{title}</h4>
      <div className="min-h-0 max-h-72 flex-1 overflow-auto">
        <table className="min-w-full divide-y divide-slate-200 text-sm">
          <thead className="sticky top-0 z-1 bg-slate-50 text-left text-xs text-slate-500">
            <tr>
              <th className="px-3 py-2">月</th>
              <th className="px-3 py-2">カテゴリ</th>
              <th className="px-3 py-2 text-right">金額</th>
              <th className="px-3 py-2">メモ</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {rows.length === 0 ? (
              <tr>
                <td colSpan={4} className="px-3 py-4 text-center text-xs text-slate-500">
                  該当する行がありません
                </td>
              </tr>
            ) : (
              rows.map((r) => (
                <tr key={r.key} className={r.warn ? "bg-amber-50" : undefined}>
                  <td className="px-3 py-2 whitespace-nowrap">{r.month}</td>
                  <td className="px-3 py-2 text-slate-800">{r.category}</td>
                  <td className="px-3 py-2 text-right font-medium">¥{r.amount.toLocaleString("ja-JP")}</td>
                  <td className="max-w-48 truncate px-3 py-2 text-slate-600" title={r.memo ?? undefined}>
                    {r.memo ?? "—"}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}

export function ImportModal({ onClose, onImported }: Props) {
  const [rawJson, setRawJson] = useState("")
  const [phase, setPhase] = useState<"edit" | "preview">("edit")
  const [pendingRows, setPendingRows] = useState<PendingImportRow[] | null>(null)
  const [compareMonthInput, setCompareMonthInput] = useState<string>("")
  const [existingExpenses, setExistingExpenses] = useState<ExpenseMaster[] | null>(null)
  const [existingLoad, setExistingLoad] = useState<"idle" | "loading" | "success" | "error">("idle")
  const [existingLoadError, setExistingLoadError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [copyStatus, setCopyStatus] = useState<"idle" | "done" | "error">("idle")
  const [selectedImportLineNumbers, setSelectedImportLineNumbers] = useState<ReadonlySet<number>>(() => new Set())
  const bundle = useFetch(() => Promise.all([api.minorCategories(), api.paymentMethods(), api.userPreferences()]))
  const expenseMinors = useMemo(
    () =>
      bundle.status === "success"
        ? sortMinorCategories(bundle.data[0].filter((m) => m.major_category.kind === "expense"))
        : [],
    [bundle],
  )
  const methods = useMemo(
    () => (bundle.status === "success" ? bundle.data[1] : []),
    [bundle],
  )

  const fixedPaymentMethod = useMemo(
    () => methods.find((m) => m.name === FIXED_PAYMENT_METHOD_NAME) ?? null,
    [methods],
  )

  useEffect(() => {
    if (phase !== "preview") return
    let cancelled = false
    void api
      .expenses()
      .then((data) => {
        if (cancelled) return
        setExistingExpenses(data)
        setExistingLoad("success")
      })
      .catch((err: unknown) => {
        if (cancelled) return
        setExistingLoad("error")
        setExistingLoadError(apiErrorMessage(err))
      })
    return () => {
      cancelled = true
    }
  }, [phase])

  const findMinorByCategoryText = (text: string) => {
    const key = text.trim()
    return (
      expenseMinors.find((m) => `${m.major_category.name} / ${m.name}` === key) ??
      expenseMinors.find((m) => m.name === key)
    )
  }

  const toMonthDate = (row: ImportRow): string => {
    if (row.month) {
      const yyyymm = parseImportMonthField(row.month)
      if (!yyyymm) throw new Error("month（YYYY-MM または YYYY年MM月）が必要です")
      return `${yyyymm}-01`
    }
    if (row.payment_date) return `${String(row.payment_date).slice(0, 7)}-01`
    throw new Error("month（YYYY-MM または YYYY年MM月）が必要です")
  }

  /** プロンプト内 {{month}} の基準となる YYYY-MM（比較月が未設定なら暦月、プレビュー中は JSON からの最小月も可）。コピー本文では YYYY年MM月 に整形される */
  const importPromptMonth = useMemo(() => {
    if (/^\d{4}-\d{2}$/.test(compareMonthInput)) return compareMonthInput
    if (pendingRows && pendingRows.length > 0) return minMonthLabel(pendingRows)
    const d = new Date()
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`
  }, [compareMonthInput, pendingRows])

  const claudePrompt = useMemo(() => {
    if (bundle.status !== "success") {
      return "マスタを読み込み中です。しばらくしてから再度「プロンプトをコピー」してください。"
    }
    if (!fixedPaymentMethod) {
      return `支払方法「${FIXED_PAYMENT_METHOD_NAME}」がマスタにありません。支出・収入タブの支払方法で「${FIXED_PAYMENT_METHOD_NAME}」（クレジットカード）を追加してからプロンプトを使ってください。`
    }
    if (fixedPaymentMethod.method_type !== "card") {
      return `取り込みは翌月クレカ前提のため、支払方法「${FIXED_PAYMENT_METHOD_NAME}」の種別をクレジットカードにしてください。`
    }
    if (expenseMinors.length === 0) {
      return "支出の小カテゴリがありません。先にマスタを整えてください。"
    }

    const catalog = expenseMinors
      .map((m) => `- id ${m.id}: ${m.major_category.name} / ${m.name}`)
      .join("\n")

    return buildImportClaudePrompt({
      catalog,
      paymentMethodName: FIXED_PAYMENT_METHOD_NAME,
      exampleMinorId: expenseMinors[0]?.id ?? 1,
      month: importPromptMonth,
      savedTemplate: bundle.data[2].import_claude_prompt_template,
    })
  }, [bundle, expenseMinors, fixedPaymentMethod, importPromptMonth])

  const buildPendingRows = (): PendingImportRow[] => {
    const rows = JSON.parse(rawJson) as ImportRow[]
    if (!Array.isArray(rows)) {
      throw new Error("JSON配列で入力してください")
    }
    return rows.map((row, index) => {
      const lineNumber = index + 1
      const idRaw = row.minor_category_id
      let minor: MinorCategory
      if (idRaw != null && Number.isFinite(Number(idRaw))) {
        const id = Number(idRaw)
        const found = expenseMinors.find((m) => m.id === id)
        if (!found) throw new Error(`${lineNumber}行目: minor_category_id ${id} は支出の小カテゴリにありません`)
        minor = found
      } else if (row.category != null && String(row.category).trim() !== "") {
        const found = findMinorByCategoryText(String(row.category))
        if (!found) throw new Error(`${lineNumber}行目: category が見つかりません (${row.category})`)
        minor = found
      } else {
        throw new Error(`${lineNumber}行目: minor_category_id（数値）が必要です`)
      }

      const monthDate = toMonthDate(row)
      const amount = Number(row.amount)
      if (!Number.isFinite(amount) || amount < 0) {
        throw new Error(`${lineNumber}行目: amount は0以上の数値にしてください`)
      }

      let memo: string | null = null
      if (row.memo != null && String(row.memo).trim() !== "") {
        memo = String(row.memo).trim()
        if (memo.length > 2000) throw new Error(`${lineNumber}行目: memo は2000文字以内にしてください`)
      }

      const monthLabel = monthDate.slice(0, 7)
      const categoryPath = `${minor.major_category.name} / ${minor.name}`

      return {
        lineNumber,
        monthDate,
        monthLabel,
        categoryPath,
        amount: Math.round(amount),
        memo,
        minor,
      }
    })
  }

  const pendingRowsForCompareMonth = useMemo(() => {
    if (!pendingRows || !/^\d{4}-\d{2}$/.test(compareMonthInput)) return []
    return pendingRows.filter((pr) => pr.monthLabel === compareMonthInput)
  }, [pendingRows, compareMonthInput])

  const existingRows = useMemo(() => {
    if (!pendingRows || !existingExpenses || !/^\d{4}-\d{2}$/.test(compareMonthInput)) return []
    return buildExistingRows(existingExpenses, expenseMinors, compareMonthInput, pendingRowsForCompareMonth)
  }, [existingExpenses, expenseMinors, compareMonthInput, pendingRows, pendingRowsForCompareMonth])

  const pendingDuplicateLineNumbers = useMemo(() => {
    if (!pendingRows || !compareMonthInput) return new Set<number>()
    const set = new Set<number>()
    for (const pr of pendingRows) {
      if (pr.monthLabel !== compareMonthInput) continue
      const dup = existingRows.some((er) => er.minorCategoryId === pr.minor.id && er.amount === pr.amount)
      if (dup) set.add(pr.lineNumber)
    }
    return set
  }, [pendingRows, compareMonthInput, existingRows])

  const effectiveSelectedImportLineNumbers = useMemo(() => {
    if (phase !== "preview" || existingLoad !== "success") {
      return selectedImportLineNumbers
    }
    const next = new Set(selectedImportLineNumbers)
    for (const lineNumber of pendingDuplicateLineNumbers) {
      next.delete(lineNumber)
    }
    return next
  }, [selectedImportLineNumbers, phase, existingLoad, pendingDuplicateLineNumbers])

  const hiddenDuplicateCount = pendingDuplicateLineNumbers.size

  const leftTableRows = useMemo(
    () =>
      existingRows
        .filter((er) => !er.duplicateWithPending)
        .map((er) => ({
          key: er.id,
          month: er.monthLabel,
          category: er.categoryPath,
          amount: er.amount,
          memo: er.memo,
          warn: false,
        })),
    [existingRows],
  )

  const rightTableRows = useMemo(() => {
    if (!pendingRows) return []
    const mapped = pendingRows
      .filter((r) => !pendingDuplicateLineNumbers.has(r.lineNumber))
      .map((r) => ({
        key: r.lineNumber,
        lineNumber: r.lineNumber,
        month: r.monthLabel,
        category: r.categoryPath,
        amount: r.amount,
        memo: r.memo,
        warn: false,
      }))
    mapped.sort((a, b) => {
      const cat = a.category.localeCompare(b.category, "ja")
      if (cat !== 0) return cat
      if (a.amount !== b.amount) return a.amount - b.amount
      return a.lineNumber - b.lineNumber
    })
    return mapped
  }, [pendingRows, pendingDuplicateLineNumbers])

  const selectedImportCount = effectiveSelectedImportLineNumbers.size
  const selectedImportAmount = useMemo(() => {
    if (!pendingRows) return 0
    return pendingRows.reduce((s, r) =>
      effectiveSelectedImportLineNumbers.has(r.lineNumber) ? s + r.amount : s,
    0)
  }, [pendingRows, effectiveSelectedImportLineNumbers])

  const toggleImportLine = useCallback((lineNumber: number, checked: boolean) => {
    setSelectedImportLineNumbers((prev) => {
      const next = new Set(prev)
      if (checked) next.add(lineNumber)
      else next.delete(lineNumber)
      return next
    })
  }, [])

  const selectAllImportLines = useCallback(() => {
    if (!pendingRows) return
    setSelectedImportLineNumbers(new Set(pendingRows.map((r) => r.lineNumber)))
  }, [pendingRows])

  const selectNoImportLines = useCallback(() => {
    setSelectedImportLineNumbers(new Set())
  }, [])

  const onConfirmPreview = () => {
    if (bundle.status !== "success") return
    if (!fixedPaymentMethod) {
      setErrorMessage(`支払方法「${FIXED_PAYMENT_METHOD_NAME}」がマスタにありません。先に登録してください。`)
      return
    }
    if (fixedPaymentMethod.method_type !== "card") {
      setErrorMessage(
        `取り込みは翌月クレカ前提です。「${FIXED_PAYMENT_METHOD_NAME}」の種別をクレジットカードにしてから再度お試しください。`,
      )
      return
    }
    setErrorMessage(null)
    try {
      const parsed = buildPendingRows()
      if (parsed.length === 0) {
        setErrorMessage("取り込む行がありません")
        return
      }
      setPendingRows(parsed)
      setSelectedImportLineNumbers(new Set(parsed.map((r) => r.lineNumber)))
      setCompareMonthInput(minMonthLabel(parsed))
      setExistingExpenses(null)
      setExistingLoad("loading")
      setExistingLoadError(null)
      setPhase("preview")
    } catch (error) {
      setErrorMessage(apiErrorMessage(error))
    }
  }

  const backToEdit = () => {
    setPhase("edit")
    setPendingRows(null)
    setCompareMonthInput("")
    setErrorMessage(null)
    setExistingExpenses(null)
    setExistingLoad("idle")
    setExistingLoadError(null)
    setSelectedImportLineNumbers(new Set())
  }

  const executeImport = async () => {
    if (bundle.status !== "success" || !fixedPaymentMethod || !pendingRows?.length) return
    if (fixedPaymentMethod.method_type !== "card") {
      setErrorMessage(
        `取り込みは翌月クレカ前提です。「${FIXED_PAYMENT_METHOD_NAME}」の種別をクレジットカードにしてください。`,
      )
      return
    }
    const rowsToImport = pendingRows.filter((r) => effectiveSelectedImportLineNumbers.has(r.lineNumber))
    if (rowsToImport.length === 0) {
      setErrorMessage("取り込む行を1件以上選んでください")
      return
    }

    setSubmitting(true)
    setErrorMessage(null)
    try {
      await api.updatePaymentMethod(fixedPaymentMethod.id, {
        ledger_charge_timing: "next_month",
      })
      const touchedMonths = new Set<string>()
      for (const row of rowsToImport) {
        await api.createExpense({
          minor_category_id: row.minor.id,
          payment_method_id: fixedPaymentMethod.id,
          expense_type: "one_time",
          recurring_cycle: "monthly",
          renewal_month: null,
          amount: row.amount,
          start_month: row.monthDate,
          end_month: row.monthDate,
          memo: row.memo,
        })
        touchedMonths.add(row.monthDate)
      }
      for (const month of touchedMonths) {
        await api.syncActuals({ month, expense_scope: "one_time" })
      }
      onImported()
    } catch (error) {
      setErrorMessage(apiErrorMessage(error))
    } finally {
      setSubmitting(false)
    }
  }

  const copyPrompt = async () => {
    try {
      await navigator.clipboard.writeText(claudePrompt)
      setCopyStatus("done")
      setTimeout(() => setCopyStatus("idle"), 2000)
    } catch {
      setCopyStatus("error")
    }
  }

  const exampleId = expenseMinors[0]?.id ?? 1
  const jsonPlaceholder = `[{"month":"${importPromptMonth}","minor_category_id":${exampleId},"amount":1200,"memo":""}]`
  const promptCopyDisabled =
    bundle.status !== "success" ||
    !fixedPaymentMethod ||
    fixedPaymentMethod.method_type !== "card" ||
    expenseMinors.length === 0

  return (
    <Modal
      title="実績を取込"
      titleAside={
        <Link to="/finance/settings#import-prompt" className={actionButtonClass}>
          プロンプト編集
        </Link>
      }
      onClose={onClose}
      size={phase === "preview" ? "2xl" : "lg"}
    >
      <form className="space-y-4" onSubmit={(e) => e.preventDefault()}>
        <div className="space-y-2">
          <div className="flex flex-wrap items-center gap-2">
            <span className="min-w-[5.5rem] shrink-0 text-xs font-medium text-slate-600">取込</span>
            <button
              type="button"
              onClick={() => void copyPrompt()}
              disabled={promptCopyDisabled}
              className={actionButtonClass}
            >
              {copyStatus === "done" ? "コピー済" : "プロンプトコピー"}
            </button>
            <a href={CLAUDE_NEW_URL} target="_blank" rel="noopener noreferrer" className={externalLinkButtonClass}>
              Claude
            </a>
          </div>
          {copyStatus === "error" && (
            <p className="text-xs text-rose-700">クリップボードへのコピーに失敗しました</p>
          )}
        </div>

        {phase === "edit" && (
          <>
            {errorMessage && (
              <p className="rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700">{errorMessage}</p>
            )}
            <label className="block text-sm">
              <span className="text-slate-600">JSON</span>
              <textarea
                rows={10}
                value={rawJson}
                onChange={(e) => setRawJson(e.target.value)}
                placeholder={jsonPlaceholder}
                className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 font-mono text-xs"
              />
            </label>
          </>
        )}

        {phase === "preview" && pendingRows && (
          <div className="space-y-3">
            <p className="text-sm font-medium text-slate-800">
                左で比較する月を選び、保存済みの<strong>単発</strong>支出と今回取り込む内容を並べて確認してください（定期は出しません）。右のチェックを付けた行だけが取り込まれます。同一利用月・同一カテゴリ・同一金額の重複は一覧に表示しません。
              </p>
              <label className="flex flex-wrap items-center gap-2 text-sm">
                <span className="text-slate-600">比較する月（左の一覧）</span>
                <input
                  type="month"
                  value={compareMonthInput}
                  onChange={(e) => setCompareMonthInput(e.target.value)}
                  className="rounded-lg border border-slate-300 px-3 py-1.5 text-sm"
                />
              </label>
              {existingLoad === "loading" && <p className="text-xs text-slate-500">保存済み支出を読み込み中…</p>}
              {existingLoad === "error" && existingLoadError && (
                <p className="text-xs text-rose-700">保存済み支出の取得に失敗: {existingLoadError}</p>
              )}
              {existingLoad === "success" && hiddenDuplicateCount > 0 && (
                <p className="text-xs text-amber-800">
                  保存済みと重複する {hiddenDuplicateCount} 件は表示・取り込み対象から除いています。
                </p>
              )}
              <div className="flex flex-col gap-4 lg:flex-row lg:items-stretch">
                <ImportPreviewTable title="保存済みの単発支出" rows={leftTableRows} />
                <ImportPendingTable
                  title="今回取り込む（単発）"
                  rows={rightTableRows}
                  selectedLineNumbers={effectiveSelectedImportLineNumbers}
                  onToggleLine={toggleImportLine}
                  onSelectAll={selectAllImportLines}
                  onSelectNone={selectNoImportLines}
                />
              </div>
              <p className="text-xs text-slate-500">
                取り込み対象: {selectedImportCount} 件 / ¥{selectedImportAmount.toLocaleString("ja-JP")}（JSON 全体{" "}
                {pendingRows.length} 件 / ¥{pendingRows.reduce((s, r) => s + r.amount, 0).toLocaleString("ja-JP")}）
              </p>
              {errorMessage && (
                <p className="rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700">{errorMessage}</p>
              )}
            </div>
          )}

        <div className="flex flex-wrap justify-end gap-2 border-t border-slate-100 pt-3">
          {phase === "edit" ? (
            <>
              <button
                type="button"
                onClick={onClose}
                className="rounded-lg border border-slate-300 px-3 py-2 text-sm hover:bg-slate-50"
              >
                キャンセル
              </button>
              <button
                type="button"
                onClick={() => void onConfirmPreview()}
                disabled={promptCopyDisabled || rawJson.trim() === ""}
                className="rounded-lg bg-indigo-600 px-3 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:cursor-not-allowed disabled:bg-indigo-300"
              >
                内容を確認
              </button>
            </>
          ) : (
            <>
              <button
                type="button"
                onClick={backToEdit}
                disabled={submitting}
                className="rounded-lg border border-slate-300 px-3 py-2 text-sm hover:bg-slate-50 disabled:opacity-50"
              >
                戻って修正
              </button>
              <button
                type="button"
                onClick={() => void executeImport()}
                disabled={submitting || selectedImportCount === 0}
                className="rounded-lg bg-indigo-600 px-3 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:cursor-not-allowed disabled:bg-indigo-300"
              >
                {submitting ? "取込中…" : "選択した行を取り込む"}
              </button>
            </>
          )}
        </div>
      </form>
    </Modal>
  )
}
