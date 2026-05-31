import { useCallback, useEffect, useMemo, useState } from "react"
import { Link } from "react-router-dom"
import { FormError, Modal } from "../components/Modal.tsx"
import { api, type StockDailyNote, type StockDailyNoteUpsertInput } from "../lib/api.ts"
import { apiErrorMessage } from "../lib/errors.ts"
import {
  applyStockPromptPlaceholders,
  formatRecordDateJp,
  hypothesisForResultPromptFromRows,
  resultBodyFromRows,
  resultForResultPromptFromRows,
  stockDailyPromptsFromPrefs,
  usesPrevDayFallbackForStockPromptCopy,
} from "../lib/stockDailyPrompts.ts"

type PromptBundle = { hypothesis: string; result: string; sector: string }

type EditFieldKey = "hypothesis" | "result" | "sector"

const FIELD_LABEL: Record<EditFieldKey, string> = {
  hypothesis: "仮説",
  result: "結果",
  sector: "セクター調べ",
}

type DashboardStockRow =
  | { key: string; kind: "no_record"; date: string }
  | { key: string; kind: "missing_field"; date: string; field: EditFieldKey; label: string }

function todayIsoDate(): string {
  const d = new Date()
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, "0")
  const day = String(d.getDate()).padStart(2, "0")
  return `${y}-${m}-${day}`
}

function yesterdayIsoDate(): string {
  const d = new Date()
  d.setDate(d.getDate() - 1)
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, "0")
  const day = String(d.getDate()).padStart(2, "0")
  return `${y}-${m}-${day}`
}

const FIELD_SPECS: {
  field: EditFieldKey
  label: string
  pick: (n: StockDailyNote) => string | undefined | null
}[] = [
  { field: "hypothesis", label: "仮説", pick: (n) => n.hypothesis },
  { field: "result", label: "結果", pick: (n) => n.result },
  { field: "sector", label: "セクター調べ", pick: (n) => n.sector_research },
]

function promptCopyButtonLabel(field: EditFieldKey, copied: boolean): string {
  const base =
    field === "hypothesis"
      ? "仮説プロンプトコピー"
      : field === "result"
        ? "結果プロンプトコピー"
        : "セクター調べプロンプトコピー"
  return copied ? `${base}済` : base
}

function hypothesisBodyForDate(notes: StockDailyNote[], isoDate: string): string {
  const n = notes.find((x) => x.recorded_on.slice(0, 10) === isoDate)
  return n?.hypothesis ?? ""
}

function mergeUpsertedNote(prev: StockDailyNote[], saved: StockDailyNote): StockDailyNote[] {
  const key = saved.recorded_on.slice(0, 10)
  const rest = prev.filter((n) => n.recorded_on.slice(0, 10) !== key)
  return [...rest, saved].sort((a, b) => (a.recorded_on < b.recorded_on ? 1 : -1))
}

/** 当日・前日のみ。レコードが無い日は1行にまとめる */
function buildDashboardStockRows(notes: StockDailyNote[]): DashboardStockRow[] {
  const t = todayIsoDate()
  const y = yesterdayIsoDate()
  const byDate = new Map<string, StockDailyNote>()
  for (const n of notes) {
    byDate.set(n.recorded_on.slice(0, 10), n)
  }
  const dates = [t, y].sort((a, b) => b.localeCompare(a))
  const out: DashboardStockRow[] = []
  for (const date of dates) {
    const note = byDate.get(date)
    if (!note) {
      out.push({ key: `no-record:${date}`, kind: "no_record", date })
    } else {
      for (const spec of FIELD_SPECS) {
        if (!String(spec.pick(note) ?? "").trim()) {
          out.push({
            key: `field:${date}:${spec.field}`,
            kind: "missing_field",
            date,
            field: spec.field,
            label: spec.label,
          })
        }
      }
    }
  }
  return out
}

const btnSm =
  "inline-flex items-center justify-center rounded-md border border-slate-300 bg-white px-2.5 py-1 text-xs font-medium text-slate-800 hover:bg-slate-50"

export function DashboardPage() {
  const [notes, setNotes] = useState<StockDailyNote[]>([])
  const [prompts, setPrompts] = useState<PromptBundle>({ hypothesis: "", result: "", sector: "" })
  const [notesLoading, setNotesLoading] = useState(true)
  const [notesError, setNotesError] = useState<string | null>(null)
  const [copyError, setCopyError] = useState<string | null>(null)
  const [copiedKey, setCopiedKey] = useState<string | null>(null)

  const [createModalDate, setCreateModalDate] = useState<string | null>(null)
  const [createHypothesis, setCreateHypothesis] = useState("")
  const [createError, setCreateError] = useState<string | null>(null)
  const [createSaving, setCreateSaving] = useState(false)

  const [fieldEdit, setFieldEdit] = useState<{ date: string; field: EditFieldKey } | null>(null)
  const [fieldDraft, setFieldDraft] = useState("")
  const [fieldSaveError, setFieldSaveError] = useState<string | null>(null)
  const [fieldSaving, setFieldSaving] = useState(false)

  const loadDashboardData = useCallback(async () => {
    setNotesLoading(true)
    setNotesError(null)
    try {
      const [list, prefs] = await Promise.all([api.stockDailyNotes(), api.userPreferences()])
      setNotes(list)
      setPrompts(stockDailyPromptsFromPrefs(prefs))
    } catch (err) {
      setNotesError(apiErrorMessage(err))
    } finally {
      setNotesLoading(false)
    }
  }, [])

  useEffect(() => {
    queueMicrotask(() => {
      void loadDashboardData()
    })
  }, [loadDashboardData])

  useEffect(() => {
    const onVis = () => {
      if (document.visibilityState !== "visible") return
      if (createModalDate != null || fieldEdit != null) return
      void loadDashboardData()
    }
    document.addEventListener("visibilitychange", onVis)
    return () => document.removeEventListener("visibilitychange", onVis)
  }, [loadDashboardData, createModalDate, fieldEdit])

  const rows = useMemo(() => buildDashboardStockRows(notes), [notes])
  const remainingCount = rows.length

  const copyPromptForDate = useCallback(
    async (field: EditFieldKey, date: string, feedbackKey: string) => {
      setCopyError(null)
      const raw =
        field === "hypothesis" ? prompts.hypothesis : field === "result" ? prompts.result : prompts.sector
      const prevDayFallback = usesPrevDayFallbackForStockPromptCopy(field)
      const hypothesisBody = prevDayFallback
        ? hypothesisForResultPromptFromRows(
            notes.map((n) => ({ date: n.recorded_on, hypothesis: n.hypothesis })),
            date,
          )
        : hypothesisBodyForDate(notes, date)
      const noteRows = notes.map((n) => ({ date: n.recorded_on, result: n.result }))
      const resultBody = prevDayFallback
        ? resultForResultPromptFromRows(noteRows, date)
        : resultBodyFromRows(noteRows, date)
      const forClipboard = applyStockPromptPlaceholders(raw, date, hypothesisBody, resultBody)
      try {
        await navigator.clipboard.writeText(forClipboard)
        setCopiedKey(feedbackKey)
        window.setTimeout(() => {
          setCopiedKey((c) => (c === feedbackKey ? null : c))
        }, 2000)
      } catch {
        setCopyError("クリップボードへのコピーに失敗しました")
      }
    },
    [notes, prompts.hypothesis, prompts.result, prompts.sector],
  )

  const openCreateModal = (date: string) => {
    setCreateModalDate(date)
    setCreateHypothesis("")
    setCreateError(null)
  }

  const closeCreateModal = () => {
    setCreateModalDate(null)
    setCreateHypothesis("")
    setCreateError(null)
  }

  const saveCreateModal = async () => {
    if (!createModalDate) return
    setCreateError(null)
    if (!createHypothesis.trim()) {
      setCreateError("仮説を入力してください")
      return
    }
    setCreateSaving(true)
    try {
      const input: StockDailyNoteUpsertInput = {
        recorded_on: createModalDate,
        hypothesis: createHypothesis,
        result: "",
        sector_research: "",
      }
      const saved = await api.upsertStockDailyNote(input)
      setNotes((prev) => mergeUpsertedNote(prev, saved))
      closeCreateModal()
    } catch (err) {
      setCreateError(apiErrorMessage(err))
    } finally {
      setCreateSaving(false)
    }
  }

  const openFieldEditModal = (date: string, field: EditFieldKey) => {
    const n = notes.find((x) => x.recorded_on.slice(0, 10) === date)
    const initial =
      field === "hypothesis"
        ? (n?.hypothesis ?? "")
        : field === "result"
          ? (n?.result ?? "")
          : (n?.sector_research ?? "")
    setFieldSaveError(null)
    setFieldDraft(initial)
    setFieldEdit({ date, field })
  }

  const closeFieldEditModal = () => {
    setFieldEdit(null)
    setFieldDraft("")
    setFieldSaveError(null)
  }

  const saveFieldEditModal = async () => {
    if (!fieldEdit) return
    setFieldSaveError(null)
    const existing = notes.find((n) => n.recorded_on.slice(0, 10) === fieldEdit.date)
    if (!existing) {
      setFieldSaveError("記録が見つかりません。再読み込みしてから試してください。")
      return
    }
    setFieldSaving(true)
    try {
      const input: StockDailyNoteUpsertInput = {
        recorded_on: fieldEdit.date,
        hypothesis: fieldEdit.field === "hypothesis" ? fieldDraft : existing.hypothesis ?? "",
        result: fieldEdit.field === "result" ? fieldDraft : existing.result ?? "",
        sector_research: fieldEdit.field === "sector" ? fieldDraft : existing.sector_research ?? "",
      }
      const saved = await api.upsertStockDailyNote(input)
      setNotes((prev) => mergeUpsertedNote(prev, saved))
      closeFieldEditModal()
    } catch (err) {
      setFieldSaveError(apiErrorMessage(err))
    } finally {
      setFieldSaving(false)
    }
  }

  return (
    <div className="space-y-4">
      {createModalDate != null && (
        <Modal title="記録を作成" onClose={closeCreateModal} size="md">
          <div className="space-y-4">
            <p className="text-sm text-slate-700">
              記録日: <span className="font-medium">{formatRecordDateJp(createModalDate)}</span>
            </p>
            <label className="block text-sm text-slate-700">
              仮説（マークダウン）
              <textarea
                value={createHypothesis}
                onChange={(e) => setCreateHypothesis(e.target.value)}
                rows={12}
                spellCheck={false}
                placeholder={"この日の仮説（マークダウン可）\n# 見出し\n- 項目"}
                className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 font-mono text-sm leading-relaxed"
              />
            </label>
            <FormError message={createError} />
            <div className="flex flex-wrap justify-end gap-2 border-t border-slate-100 pt-3">
              <button
                type="button"
                onClick={closeCreateModal}
                disabled={createSaving}
                className="rounded-lg border border-slate-300 px-3 py-2 text-sm hover:bg-slate-50 disabled:opacity-50"
              >
                キャンセル
              </button>
              <button
                type="button"
                onClick={() => void saveCreateModal()}
                disabled={createSaving}
                className="rounded-lg bg-indigo-600 px-3 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:cursor-not-allowed disabled:bg-indigo-300"
              >
                {createSaving ? "保存中…" : "保存"}
              </button>
            </div>
          </div>
        </Modal>
      )}

      {fieldEdit != null && (
        <Modal
          title={`${FIELD_LABEL[fieldEdit.field]}を編集（${formatRecordDateJp(fieldEdit.date)}）`}
          onClose={closeFieldEditModal}
          size="lg"
        >
          <p className="mb-2 text-xs text-slate-500">マークダウンで入力してください。</p>
          <textarea
            value={fieldDraft}
            onChange={(e) => setFieldDraft(e.target.value)}
            rows={18}
            spellCheck={false}
            placeholder={"# 見出し\n- リスト\n```\nコード\n```"}
            className="w-full rounded-lg border border-slate-300 px-3 py-2 font-mono text-sm leading-relaxed"
          />
          <FormError message={fieldSaveError} />
          <div className="mt-4 flex flex-wrap justify-end gap-2 border-t border-slate-100 pt-3">
            <button
              type="button"
              onClick={closeFieldEditModal}
              disabled={fieldSaving}
              className="rounded-lg border border-slate-300 px-3 py-2 text-sm hover:bg-slate-50 disabled:opacity-50"
            >
              キャンセル
            </button>
            <button
              type="button"
              onClick={() => void saveFieldEditModal()}
              disabled={fieldSaving}
              className="rounded-lg bg-indigo-600 px-3 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:cursor-not-allowed disabled:bg-indigo-300"
            >
              {fieldSaving ? "保存中…" : "保存"}
            </button>
          </div>
        </Modal>
      )}

      <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <h2 className="text-xl font-bold">ダッシュボード</h2>
        <p className="mt-2 text-sm text-indigo-700">毎日の記録の未入力: {remainingCount}件</p>
      </section>

      <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <h3 className="text-sm font-semibold text-slate-800">TODO（毎日の記録）</h3>
          <Link
            to="/stocks/daily"
            className="text-sm font-medium text-indigo-700 underline-offset-2 hover:underline"
          >
            毎日の記録を開く
          </Link>
        </div>
        <p className="mt-1 text-xs text-slate-500">
          当日と前日だけを対象に確認表示します。作成・編集はこの画面のモーダルで行えます（一覧の確認は毎日の記録へ）。
        </p>
        {notesError != null ? (
          <p className="mt-3 text-sm text-red-600" role="alert">
            {notesError}
          </p>
        ) : null}
        {copyError != null ? (
          <p className="mt-3 text-sm text-red-600" role="alert">
            {copyError}
          </p>
        ) : null}
        {notesLoading ? (
          <p className="mt-3 text-sm text-slate-500">読み込み中…</p>
        ) : rows.length === 0 ? (
          <p className="mt-3 text-sm text-slate-500">未入力の項目はありません。</p>
        ) : (
          <ul className="mt-3 space-y-2">
            {rows.map((row) => {
              if (row.kind === "no_record") {
                const fk = `nr:${row.date}`
                return (
                  <li
                    key={row.key}
                    className="flex flex-col gap-2 rounded-lg border border-slate-200 px-3 py-2.5 sm:flex-row sm:items-center sm:justify-between"
                  >
                    <p className="text-sm text-slate-700">
                      <span className="font-medium">{formatRecordDateJp(row.date)}</span>
                      の記録がありません。
                    </p>
                    <div className="flex flex-wrap items-center gap-2">
                      <button
                        type="button"
                        className={btnSm}
                        onClick={() => void copyPromptForDate("hypothesis", row.date, fk)}
                      >
                        {promptCopyButtonLabel("hypothesis", copiedKey === fk)}
                      </button>
                      <button type="button" className={btnSm} onClick={() => openCreateModal(row.date)}>
                        作成
                      </button>
                    </div>
                  </li>
                )
              }
              const fk = `mf:${row.date}:${row.field}`
              return (
                <li
                  key={row.key}
                  className="flex flex-col gap-2 rounded-lg border border-slate-200 px-3 py-2.5 sm:flex-row sm:items-center sm:justify-between"
                >
                  <p className="text-sm text-slate-700">
                    {formatRecordDateJp(row.date)}の{row.label}が未入力です
                  </p>
                  <div className="flex flex-wrap items-center gap-2">
                    <button
                      type="button"
                      className={btnSm}
                      onClick={() => void copyPromptForDate(row.field, row.date, fk)}
                    >
                      {promptCopyButtonLabel(row.field, copiedKey === fk)}
                    </button>
                    <button type="button" className={btnSm} onClick={() => openFieldEditModal(row.date, row.field)}>
                      編集
                    </button>
                  </div>
                </li>
              )
            })}
          </ul>
        )}
      </section>
    </div>
  )
}
