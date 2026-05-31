import { useCallback, useEffect, useMemo, useState } from "react"
import ReactMarkdown from "react-markdown"
import remarkBreaks from "remark-breaks"
import { FormActions, FormError, Modal } from "../components/Modal.tsx"
import { api, type StockDailyNote, type StockDailyNoteUpsertInput } from "../lib/api.ts"
import { apiErrorMessage } from "../lib/errors.ts"
import {
  applyStockPromptPlaceholders,
  formatRecordDateJp,
  hypothesisForResultPromptFromRows,
  normalizeCalendarDateKey,
  resultBodyFromRows,
  resultForResultPromptFromRows,
  usesPrevDayFallbackForStockPromptCopy,
  stockDailyPromptsFromPrefs,
} from "../lib/stockDailyPrompts.ts"

type StockDailyRow = {
  id: string
  date: string
  /** 仮説 */
  hypothesis: string
  result: string
  sectorResearch: string
  createdAt: string
}

const STORAGE_KEY = "solarc:stock-daily-notes:v1"

type EditField = "hypothesis" | "result" | "sector"

const FIELD_LABEL: Record<EditField, string> = {
  hypothesis: "仮説",
  result: "結果",
  sector: "セクター調べ",
}

const STOCK_DAILY_EXTERNAL_LINKS = {
  claude: { label: "Claude", href: "https://claude.ai/new" },
  worldMarket: { label: "世界の市況", href: "https://nikkei225jp.com/" },
  todayMarket: {
    label: "本日の市況",
    href: "https://www.sc.mufg.jp/market/today_market/index.html",
  },
  japanMarket: { label: "日本の市況", href: "https://nikkei225jp.com/chart/" },
} as const

type StockDailyExternalLinkKey = keyof typeof STOCK_DAILY_EXTERNAL_LINKS

const STOCK_DAILY_WORKFLOW_GROUPS: {
  field: EditField
  copyKey: "hypothesis" | "result" | "sector"
  links: StockDailyExternalLinkKey[]
}[] = [
  { field: "hypothesis", copyKey: "hypothesis", links: ["claude", "worldMarket"] },
  { field: "result", copyKey: "result", links: ["claude", "todayMarket", "japanMarket"] },
  { field: "sector", copyKey: "sector", links: ["claude"] },
]

const actionButtonClass =
  "inline-flex h-9 w-full shrink-0 items-center justify-center rounded-lg border border-slate-300 bg-white px-2 text-xs font-medium text-slate-800 hover:bg-slate-50 sm:h-auto sm:w-auto sm:px-3 sm:py-1.5 sm:text-sm"

const externalLinkButtonClass =
  "inline-flex h-9 w-full shrink-0 items-center justify-center rounded-lg border border-indigo-200 bg-white px-2 text-xs font-medium text-indigo-700 hover:bg-indigo-50 sm:h-auto sm:w-auto sm:px-3 sm:py-1.5 sm:text-sm"

function upsertRowField(
  rows: StockDailyRow[],
  recordDate: string,
  field: EditField,
  value: string,
): StockDailyRow[] {
  const existing = rows.find((r) => r.date === recordDate)
  const now = new Date().toISOString()
  const nextRow: StockDailyRow = existing
    ? {
        ...existing,
        hypothesis: field === "hypothesis" ? value : existing.hypothesis,
        result: field === "result" ? value : existing.result,
        sectorResearch: field === "sector" ? value : existing.sectorResearch,
      }
    : {
        id: crypto.randomUUID(),
        date: recordDate,
        hypothesis: field === "hypothesis" ? value : "",
        result: field === "result" ? value : "",
        sectorResearch: field === "sector" ? value : "",
        createdAt: now,
      }
  const empty =
    !nextRow.hypothesis.trim() && !nextRow.result.trim() && !nextRow.sectorResearch.trim()
  const rest = rows.filter((r) => r.date !== recordDate)
  if (empty) return rest
  return [nextRow, ...rest]
}

function readRows(): StockDailyRow[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return []
    const parsed = JSON.parse(raw) as unknown[]
    if (!Array.isArray(parsed)) return []
    const out: StockDailyRow[] = []
    for (const item of parsed) {
      const row = normalizeStoredRow(item)
      if (row) out.push(row)
    }
    return out
  } catch {
    return []
  }
}

function normalizeStoredRow(item: unknown): StockDailyRow | null {
  if (item == null || typeof item !== "object") return null
  const o = item as Record<string, unknown>
  if (typeof o.id !== "string" || typeof o.date !== "string" || typeof o.createdAt !== "string") return null

  if (typeof o.hypothesis === "string" && typeof o.result === "string" && typeof o.sectorResearch === "string") {
    return {
      id: o.id,
      date: o.date,
      hypothesis: o.hypothesis,
      result: o.result,
      sectorResearch: o.sectorResearch,
      createdAt: o.createdAt,
    }
  }

  if (typeof o.content === "string") {
    return {
      id: o.id,
      date: o.date,
      hypothesis: o.content,
      result: "",
      sectorResearch: "",
      createdAt: o.createdAt,
    }
  }

  return null
}

function isPersistedStockNoteId(id: string): boolean {
  return /^\d+$/.test(id)
}

function rowSignature(r: StockDailyRow): string {
  return `${r.hypothesis.trim()}\n${r.result.trim()}\n${r.sectorResearch.trim()}`
}

function fromApiNote(n: StockDailyNote): StockDailyRow {
  return {
    id: String(n.id),
    date: n.recorded_on.slice(0, 10),
    hypothesis: n.hypothesis ?? "",
    result: n.result ?? "",
    sectorResearch: n.sector_research ?? "",
    createdAt: n.updated_at,
  }
}

function sortStockDailyRows(list: StockDailyRow[]): StockDailyRow[] {
  return [...list].sort((a, b) => (a.date < b.date ? 1 : -1))
}

function toUpsertBody(r: StockDailyRow): StockDailyNoteUpsertInput {
  return {
    recorded_on: r.date,
    hypothesis: r.hypothesis,
    result: r.result,
    sector_research: r.sectorResearch,
  }
}

function withRowFromUpsertResponse(prevRows: StockDailyRow[], saved: StockDailyNote): StockDailyRow[] {
  const mapped = fromApiNote(saved)
  const rest = prevRows.filter((r) => r.date !== mapped.date)
  return sortStockDailyRows([...rest, mapped])
}

/** 旧 localStorage からの取り込み（同一記録日で中身が違えばローカルをサーバへ送る） */
async function mergeLegacyLocalStorageIntoApi(apiList: StockDailyNote[]): Promise<StockDailyRow[]> {
  const legacy = readRows()
  if (legacy.length === 0) {
    return sortStockDailyRows(apiList.map(fromApiNote))
  }
  const apiRows = apiList.map(fromApiNote)
  const byDate = new Map<string, StockDailyRow>(apiRows.map((r) => [r.date, r]))
  let upsertCount = 0
  for (const l of legacy) {
    const e = byDate.get(l.date)
    if (!e || rowSignature(l) !== rowSignature(e)) {
      await api.upsertStockDailyNote(toUpsertBody(l))
      upsertCount += 1
    }
  }
  try {
    localStorage.removeItem(STORAGE_KEY)
  } catch {
    /* ignore */
  }
  if (upsertCount > 0) {
    const fresh = await api.stockDailyNotes()
    return sortStockDailyRows(fresh.map(fromApiNote))
  }
  return sortStockDailyRows([...byDate.values()])
}

export function StockDailyPage() {
  const [rows, setRows] = useState<StockDailyRow[]>([])
  const [fieldEdit, setFieldEdit] = useState<{ date: string; field: EditField } | null>(null)
  const [fieldDraft, setFieldDraft] = useState("")

  const [promptModalOpen, setPromptModalOpen] = useState(false)
  const [draftHypothesis, setDraftHypothesis] = useState("")
  const [draftResult, setDraftResult] = useState("")
  const [draftSector, setDraftSector] = useState("")
  const [promptOpenError, setPromptOpenError] = useState<string | null>(null)
  const [promptSaveError, setPromptSaveError] = useState<string | null>(null)
  const [promptSaving, setPromptSaving] = useState(false)
  const [savedStockPrompts, setSavedStockPrompts] = useState({
    hypothesis: "",
    result: "",
    sector: "",
  })
  const [promptsLoadError, setPromptsLoadError] = useState<string | null>(null)
  const [copiedKey, setCopiedKey] = useState<"hypothesis" | "result" | "sector" | null>(null)
  const [detailDate, setDetailDate] = useState<string | null>(null)

  const [createRecordOpen, setCreateRecordOpen] = useState(false)
  const [createDate, setCreateDate] = useState(today())
  const [createHypothesis, setCreateHypothesis] = useState("")
  const [createError, setCreateError] = useState<string | null>(null)
  const [notesLoading, setNotesLoading] = useState(true)
  const [notesError, setNotesError] = useState<string | null>(null)
  const [fieldSaveError, setFieldSaveError] = useState<string | null>(null)
  const [fieldSaving, setFieldSaving] = useState(false)
  const [createSaving, setCreateSaving] = useState(false)

  const sortedRows = useMemo(
    () => [...rows].sort((a, b) => (a.date < b.date ? 1 : -1)),
    [rows],
  )

  const detailRow = useMemo(
    () => (detailDate != null ? rows.find((r) => r.date === detailDate) ?? null : null),
    [rows, detailDate],
  )

  useEffect(() => {
    let cancelled = false
    void (async () => {
      try {
        const p = await api.userPreferences()
        if (cancelled) return
        setSavedStockPrompts(stockDailyPromptsFromPrefs(p))
        setPromptsLoadError(null)
      } catch (err) {
        if (!cancelled) setPromptsLoadError(apiErrorMessage(err))
      }
    })()
    return () => {
      cancelled = true
    }
  }, [])

  const loadNotes = useCallback(async () => {
    setNotesLoading(true)
    setNotesError(null)
    try {
      const list = await api.stockDailyNotes()
      const merged = await mergeLegacyLocalStorageIntoApi(list)
      setRows(merged)
    } catch (err) {
      setNotesError(apiErrorMessage(err))
    } finally {
      setNotesLoading(false)
    }
  }, [])

  useEffect(() => {
    queueMicrotask(() => {
      void loadNotes()
    })
  }, [loadNotes])

  useEffect(() => {
    const onVis = () => {
      if (document.visibilityState !== "visible") return
      if (fieldEdit != null || createRecordOpen || promptModalOpen) return
      void loadNotes()
    }
    document.addEventListener("visibilitychange", onVis)
    return () => document.removeEventListener("visibilitychange", onVis)
  }, [loadNotes, fieldEdit, createRecordOpen, promptModalOpen])

  /** 詳細を開いたあとにその日の行が消えたときだけモーダルを閉じる（同期 setState は queueMicrotask で回避） */
  useEffect(() => {
    if (detailDate == null) return
    if (rows.some((r) => r.date === detailDate)) return
    queueMicrotask(() => setDetailDate(null))
  }, [rows, detailDate])

  const openFieldEdit = (recordDate: string, field: EditField) => {
    setFieldSaveError(null)
    const row = rows.find((r) => r.date === recordDate)
    const initial =
      field === "hypothesis"
        ? (row?.hypothesis ?? "")
        : field === "result"
          ? (row?.result ?? "")
          : (row?.sectorResearch ?? "")
    setFieldDraft(initial)
    setFieldEdit({ date: recordDate, field })
  }

  const closeFieldEdit = () => {
    setFieldEdit(null)
    setFieldDraft("")
    setFieldSaveError(null)
  }

  const saveFieldEdit = async () => {
    if (!fieldEdit) return
    setFieldSaveError(null)
    setFieldSaving(true)
    const prev = rows.find((r) => r.date === fieldEdit.date)
    try {
      const next = upsertRowField(rows, fieldEdit.date, fieldEdit.field, fieldDraft)
      const removed = !next.some((r) => r.date === fieldEdit.date)
      if (removed) {
        if (prev && isPersistedStockNoteId(prev.id)) {
          await api.deleteStockDailyNote(Number(prev.id))
        }
        setRows(next)
        closeFieldEdit()
        return
      }
      const row = next.find((r) => r.date === fieldEdit.date)
      if (!row) {
        closeFieldEdit()
        return
      }
      const saved = await api.upsertStockDailyNote(toUpsertBody(row))
      setRows(withRowFromUpsertResponse(next, saved))
      closeFieldEdit()
    } catch (err) {
      setFieldSaveError(apiErrorMessage(err))
    } finally {
      setFieldSaving(false)
    }
  }

  const openCreateRecordModal = () => {
    setCreateDate(today())
    setCreateHypothesis("")
    setCreateError(null)
    setCreateRecordOpen(true)
  }

  const closeCreateRecordModal = () => {
    setCreateRecordOpen(false)
    setCreateError(null)
  }

  const saveCreateRecord = async () => {
    setCreateError(null)
    if (!createHypothesis.trim()) {
      setCreateError("仮説を入力してください")
      return
    }
    setCreateSaving(true)
    try {
      const next = upsertRowField(rows, createDate, "hypothesis", createHypothesis)
      const row = next.find((r) => r.date === createDate)
      if (!row) {
        setCreateError("保存に失敗しました")
        return
      }
      const saved = await api.upsertStockDailyNote(toUpsertBody(row))
      setRows(withRowFromUpsertResponse(next, saved))
      closeCreateRecordModal()
    } catch (err) {
      setCreateError(apiErrorMessage(err))
    } finally {
      setCreateSaving(false)
    }
  }

  const openPromptEditModal = () => {
    setPromptModalOpen(true)
    setPromptOpenError(null)
    setPromptSaveError(null)
    void (async () => {
      try {
        const prefs = await api.userPreferences()
        const s = stockDailyPromptsFromPrefs(prefs)
        setDraftHypothesis(s.hypothesis)
        setDraftResult(s.result)
        setDraftSector(s.sector)
      } catch (err) {
        setPromptOpenError(apiErrorMessage(err))
        setDraftHypothesis("")
        setDraftResult("")
        setDraftSector("")
      }
    })()
  }

  const closePromptModal = () => {
    setPromptModalOpen(false)
    setPromptOpenError(null)
    setPromptSaveError(null)
  }

  const saveStockDailyPrompts = async () => {
    setPromptSaveError(null)
    setPromptSaving(true)
    try {
      const norm = (s: string) => s.replace(/\r\n/g, "\n").trimEnd()
      const h = norm(draftHypothesis)
      const r = norm(draftResult)
      const sec = norm(draftSector)
      const data = await api.updateUserPreferences({
        stock_daily_hypothesis_prompt: h === "" ? null : h,
        stock_daily_result_prompt: r === "" ? null : r,
        stock_daily_sector_prompt: sec === "" ? null : sec,
      })
      setSavedStockPrompts(stockDailyPromptsFromPrefs(data))
      setPromptsLoadError(null)
      closePromptModal()
    } catch (err) {
      setPromptSaveError(apiErrorMessage(err))
    } finally {
      setPromptSaving(false)
    }
  }

  const copyStockPrompt = async (key: "hypothesis" | "result" | "sector") => {
    const text =
      key === "hypothesis"
        ? savedStockPrompts.hypothesis
        : key === "result"
          ? savedStockPrompts.result
          : savedStockPrompts.sector
    const recordedOn = today()
    const recordedKey = normalizeCalendarDateKey(recordedOn)
    const prevDayFallback = usesPrevDayFallbackForStockPromptCopy(key)
    const hypothesisForDay = prevDayFallback
      ? hypothesisForResultPromptFromRows(rows, recordedOn)
      : (rows.find((r) => normalizeCalendarDateKey(r.date) === recordedKey)?.hypothesis ?? "")
    const resultForDay = prevDayFallback
      ? resultForResultPromptFromRows(rows, recordedOn)
      : resultBodyFromRows(rows, recordedOn)
    const forClipboard = applyStockPromptPlaceholders(text, recordedOn, hypothesisForDay, resultForDay)
    try {
      await navigator.clipboard.writeText(forClipboard)
      setCopiedKey(key)
      window.setTimeout(() => {
        setCopiedKey((c) => (c === key ? null : c))
      }, 2000)
    } catch {
      setPromptsLoadError("クリップボードへのコピーに失敗しました")
    }
  }

  const deleteRecordRow = async (recordDate: string) => {
    const prev = rows.find((r) => r.date === recordDate)
    try {
      if (prev && isPersistedStockNoteId(prev.id)) {
        await api.deleteStockDailyNote(Number(prev.id))
      }
      setRows((curr) => curr.filter((r) => r.date !== recordDate))
      setDetailDate((d) => (d === recordDate ? null : d))
    } catch (err) {
      setNotesError(apiErrorMessage(err))
    }
  }

  const confirmDeleteRecord = (recordDate: string) => {
    const label = formatRecordDateJp(recordDate)
    if (
      !window.confirm(
        `${label}の記録を削除しますか？\n仮説・結果・セクター調べがすべて消えます。`,
      )
    ) {
      return
    }
    void deleteRecordRow(recordDate)
  }

  return (
    <div className="space-y-4">
      {promptModalOpen && (
        <Modal title="プロンプト編集" onClose={closePromptModal} size="lg">
          <p className="mt-1 text-xs text-slate-500">
            毎日の記録の仮説・結果・セクター調べ用の Claude プロンプトをそれぞれ保存します。空で保存するとその項目は未設定になります。コピー時に次のプレースホルダを置き換えます（大文字小文字無視・前後に空白可）。日付はコピー実行日の暦日です。
          </p>
          <ul className="mt-2 mb-2 list-inside list-disc text-xs text-slate-600">
            <li>
              <code className="rounded bg-slate-100 px-1">{"{{date}}"}</code> … コピー実行日（YYYY年MM月DD日）
            </li>
            <li>
              <code className="rounded bg-slate-100 px-1">{"{{hypothesis}}"}</code> …
              仮説プロンプトコピーはコピー実行日の記録の仮説。結果・セクター調べコピーはその日の仮説が空のとき前日の仮説（それも空なら空）
            </li>
            <li>
              <code className="rounded bg-slate-100 px-1">{"{{result}}"}</code> …
              仮説プロンプトコピーはコピー実行日の記録の結果。結果・セクター調べコピーはその日の結果が空のとき前日の結果（それも空なら空）
            </li>
          </ul>
          <FormError message={promptOpenError} />
          <FormError message={promptSaveError} />
          <form
            className="space-y-4"
            onSubmit={(e) => {
              e.preventDefault()
              void saveStockDailyPrompts()
            }}
          >
            <label className="block text-sm text-slate-700">
              仮説
              <textarea
                value={draftHypothesis}
                onChange={(e) => setDraftHypothesis(e.target.value)}
                rows={10}
                spellCheck={false}
                className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 font-mono text-xs leading-relaxed"
              />
            </label>
            <label className="block text-sm text-slate-700">
              結果
              <textarea
                value={draftResult}
                onChange={(e) => setDraftResult(e.target.value)}
                rows={10}
                spellCheck={false}
                className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 font-mono text-xs leading-relaxed"
              />
            </label>
            <label className="block text-sm text-slate-700">
              セクター調べ
              <textarea
                value={draftSector}
                onChange={(e) => setDraftSector(e.target.value)}
                rows={10}
                spellCheck={false}
                className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 font-mono text-xs leading-relaxed"
              />
            </label>
            <FormActions
              onCancel={closePromptModal}
              submitLabel="プロンプトを保存"
              submitting={promptSaving}
            />
          </form>
        </Modal>
      )}

      {fieldEdit && (
        <Modal
          title={`${FIELD_LABEL[fieldEdit.field]}を編集（${formatRecordDateJp(fieldEdit.date)}）`}
          onClose={closeFieldEdit}
          size="lg"
        >
          <p className="mb-2 text-xs text-slate-500">マークダウンで入力してください（詳細ではレンダリングして表示します）。</p>
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
              onClick={closeFieldEdit}
              disabled={fieldSaving}
              className="rounded-lg border border-slate-300 px-3 py-2 text-sm hover:bg-slate-50 disabled:opacity-50"
            >
              キャンセル
            </button>
            <button
              type="button"
              onClick={() => void saveFieldEdit()}
              disabled={fieldSaving}
              className="rounded-lg bg-indigo-600 px-3 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:cursor-not-allowed disabled:bg-indigo-300"
            >
              {fieldSaving ? "保存中…" : "保存"}
            </button>
          </div>
        </Modal>
      )}

      <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <div className="mb-3 flex flex-wrap items-center justify-between gap-x-3 gap-y-2">
          <h2 className="text-xl font-bold text-slate-900">毎日の記録</h2>
          <button type="button" onClick={openPromptEditModal} className={actionButtonClass}>
            プロンプト編集
          </button>
        </div>
        <div className="space-y-2">
          {STOCK_DAILY_WORKFLOW_GROUPS.map(({ field, copyKey, links }) => (
            <div key={field} className="flex flex-wrap items-center gap-2">
              <span className="min-w-[5.5rem] shrink-0 text-xs font-medium text-slate-600">{FIELD_LABEL[field]}</span>
              <button
                type="button"
                onClick={() => void copyStockPrompt(copyKey)}
                className={actionButtonClass}
              >
                {copiedKey === copyKey ? "コピー済" : "プロンプトコピー"}
              </button>
              {links.map((linkKey) => {
                const link = STOCK_DAILY_EXTERNAL_LINKS[linkKey]
                return (
                  <a
                    key={linkKey}
                    href={link.href}
                    target="_blank"
                    rel="noopener noreferrer"
                    className={externalLinkButtonClass}
                  >
                    {link.label}
                  </a>
                )
              })}
            </div>
          ))}
        </div>
        <FormError message={promptsLoadError} />
      </section>

      <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <div className="mb-3 flex flex-row flex-wrap items-center justify-between gap-x-3 gap-y-2">
          <h3 className="min-w-0 text-base font-semibold text-slate-800 sm:text-lg">保存済み記録</h3>
          <button
            type="button"
            onClick={openCreateRecordModal}
            disabled={notesLoading}
            className="inline-flex h-9 shrink-0 items-center justify-center rounded-lg bg-indigo-600 px-4 text-sm font-medium text-white hover:bg-indigo-500 disabled:cursor-not-allowed disabled:bg-indigo-300"
          >
            作成
          </button>
        </div>
        <FormError message={notesError} />
        {notesError && (
          <button
            type="button"
            onClick={() => void loadNotes()}
            className="mt-2 rounded-lg border border-slate-300 px-3 py-1.5 text-sm hover:bg-slate-50"
          >
            再読み込み
          </button>
        )}
        {notesLoading ? (
          <p className="text-sm text-slate-500">記録を読み込み中です…</p>
        ) : sortedRows.length === 0 ? (
          <p className="text-sm text-slate-500">まだ記録がありません。</p>
        ) : (
          <div className="overflow-x-auto rounded-lg border border-slate-200">
            <table className="w-full min-w-0 border-collapse text-sm">
              <thead className="bg-slate-50 text-xs text-slate-500">
                <tr>
                  <th className="border-b border-slate-200 px-2 py-2 text-left font-semibold whitespace-nowrap sm:px-3">
                    日付
                  </th>
                  <th className="border-b border-slate-200 px-2 py-2 text-center font-semibold sm:px-3">仮説</th>
                  <th className="border-b border-slate-200 px-2 py-2 text-center font-semibold sm:px-3">結果</th>
                  <th className="border-b border-slate-200 px-2 py-2 text-center font-semibold sm:px-3">セクター調べ</th>
                  <th className="border-b border-slate-200 px-2 py-2 text-center font-semibold whitespace-nowrap sm:px-3">
                    詳細
                  </th>
                  <th className="border-b border-slate-200 px-2 py-2 text-center font-semibold whitespace-nowrap sm:px-3">
                    削除
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {sortedRows.map((row) => (
                  <tr key={row.id}>
                    <td className="align-top px-2 py-2.5 font-medium whitespace-nowrap text-slate-800 sm:align-middle sm:px-3 sm:py-3">
                      {row.date}
                    </td>
                    <td className="w-28 min-w-28 border-b border-slate-100 px-1 py-2.5 align-top sm:w-32 sm:min-w-32 sm:py-3 sm:align-middle">
                      <SavedColumnCell
                        text={row.hypothesis}
                        label="仮説"
                        onEdit={() => openFieldEdit(row.date, "hypothesis")}
                      />
                    </td>
                    <td className="w-28 min-w-28 border-b border-slate-100 px-1 py-2.5 align-top sm:w-32 sm:min-w-32 sm:py-3 sm:align-middle">
                      <SavedColumnCell
                        text={row.result}
                        label="結果"
                        onEdit={() => openFieldEdit(row.date, "result")}
                      />
                    </td>
                    <td className="w-28 min-w-28 border-b border-slate-100 px-1 py-2.5 align-top sm:w-32 sm:min-w-32 sm:py-3 sm:align-middle">
                      <SavedColumnCell
                        text={row.sectorResearch}
                        label="セクター調べ"
                        onEdit={() => openFieldEdit(row.date, "sector")}
                      />
                    </td>
                    <td className="border-b border-slate-100 px-2 py-2.5 text-center align-top sm:px-3 sm:py-3 sm:align-middle">
                      <button
                        type="button"
                        onClick={() => setDetailDate(row.date)}
                        className="inline-flex h-8 shrink-0 items-center justify-center whitespace-nowrap rounded-md border border-indigo-200 bg-white px-2.5 text-xs font-medium text-indigo-700 hover:bg-indigo-50 sm:h-auto sm:py-1.5"
                      >
                        詳細
                      </button>
                    </td>
                    <td className="border-b border-slate-100 px-2 py-2.5 text-center align-top sm:px-3 sm:py-3 sm:align-middle">
                      <button
                        type="button"
                        onClick={() => confirmDeleteRecord(row.date)}
                        className="inline-flex h-8 shrink-0 items-center justify-center whitespace-nowrap rounded-md border border-rose-200 bg-white px-2.5 text-xs font-medium text-rose-700 hover:bg-rose-50 sm:h-auto sm:py-1.5"
                      >
                        削除
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      {createRecordOpen && (
        <Modal title="記録を作成" onClose={closeCreateRecordModal} size="md">
          <div className="space-y-4">
            <label className="block text-sm text-slate-700">
              記録日
              <input
                type="date"
                value={createDate}
                onChange={(e) => setCreateDate(e.target.value)}
                className="mt-1 block w-full max-w-xs rounded-lg border border-slate-300 px-3 py-2 text-sm"
              />
            </label>
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
            {createError && <p className="text-sm text-rose-700">{createError}</p>}
            <div className="flex flex-wrap justify-end gap-2 border-t border-slate-100 pt-3">
              <button
                type="button"
                onClick={closeCreateRecordModal}
                disabled={createSaving}
                className="rounded-lg border border-slate-300 px-3 py-2 text-sm hover:bg-slate-50 disabled:opacity-50"
              >
                キャンセル
              </button>
              <button
                type="button"
                onClick={() => void saveCreateRecord()}
                disabled={createSaving}
                className="rounded-lg bg-indigo-600 px-3 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:cursor-not-allowed disabled:bg-indigo-300"
              >
                {createSaving ? "保存中…" : "保存"}
              </button>
            </div>
          </div>
        </Modal>
      )}

      {detailRow && (
        <Modal title={formatRecordDateJp(detailRow.date)} onClose={() => setDetailDate(null)} size="2xl">
          <div className="grid max-h-[72vh] grid-cols-1 gap-3 overflow-y-auto pr-1 lg:grid-cols-3 lg:items-stretch">
            <DetailBlock title="仮説" body={detailRow.hypothesis} />
            <DetailBlock title="結果" body={detailRow.result} />
            <DetailBlock title="セクター調べ" body={detailRow.sectorResearch} />
          </div>
          <div className="mt-4 flex flex-wrap justify-end gap-2 border-t border-slate-100 pt-3">
            <button
              type="button"
              onClick={() => setDetailDate(null)}
              className="rounded-lg border border-slate-300 px-3 py-2 text-sm hover:bg-slate-50"
            >
              閉じる
            </button>
          </div>
        </Modal>
      )}
    </div>
  )
}

const MARKDOWN_DETAIL_CLASS =
  "min-h-0 min-w-0 text-sm text-slate-800 [&>*:first-child]:mt-0 [&_h1]:mb-2 [&_h1]:mt-3 [&_h1]:text-base [&_h1]:font-bold [&_h2]:mb-1.5 [&_h2]:mt-2.5 [&_h2]:text-sm [&_h2]:font-semibold [&_h3]:mb-1 [&_h3]:mt-2 [&_h3]:text-sm [&_h3]:font-semibold [&_p]:my-1.5 [&_p]:leading-relaxed [&_ul]:my-1.5 [&_ul]:list-disc [&_ul]:pl-5 [&_ol]:my-1.5 [&_ol]:list-decimal [&_ol]:pl-5 [&_li]:my-0.5 [&_blockquote]:my-2 [&_blockquote]:border-l-4 [&_blockquote]:border-slate-300 [&_blockquote]:pl-3 [&_blockquote]:text-slate-600 [&_code]:rounded [&_code]:bg-slate-100 [&_code]:px-1 [&_code]:py-0.5 [&_code]:font-mono [&_code]:text-xs [&_pre]:my-2 [&_pre]:max-h-48 [&_pre]:overflow-auto [&_pre]:rounded-lg [&_pre]:bg-slate-100 [&_pre]:p-2 [&_pre]:font-mono [&_pre]:text-xs [&_a]:text-indigo-600 [&_a]:underline [&_hr]:my-3 [&_table]:my-2 [&_table]:w-full [&_table]:text-xs [&_th]:border [&_th]:border-slate-200 [&_th]:bg-slate-50 [&_th]:px-2 [&_th]:py-1 [&_th]:text-left [&_td]:border [&_td]:border-slate-200 [&_td]:px-2 [&_td]:py-1 [&_strong]:font-semibold"

function DetailBlock({ title, body }: { title: string; body: string }) {
  const t = body.trim()
  return (
    <section className="flex min-h-0 min-w-0 flex-col rounded-xl border border-slate-200 bg-slate-50/40 lg:max-h-[65vh]">
      <h4 className="shrink-0 border-b border-slate-200 bg-white px-3 py-2 text-sm font-semibold text-slate-800">
        {title}
      </h4>
      <div className={`min-h-0 flex-1 overflow-y-auto p-3 ${t ? "bg-white" : ""}`}>
        {t ? (
          <div className={MARKDOWN_DETAIL_CLASS}>
            <ReactMarkdown remarkPlugins={[remarkBreaks]}>{body}</ReactMarkdown>
          </div>
        ) : (
          <p className="text-xs text-slate-400">（未入力）</p>
        )}
      </div>
    </section>
  )
}

/** 保存済み一覧の1列: ○/×と編集を横並び（装飾なしの記号のみ） */
function SavedColumnCell({
  text,
  label,
  onEdit,
}: {
  text: string
  label: string
  onEdit: () => void
}) {
  const filled = text.trim().length > 0
  return (
    <div className="mx-auto flex max-w-full flex-nowrap items-center justify-center gap-1.5">
      <span
        className={`shrink-0 text-base font-semibold tabular-nums leading-none ${filled ? "text-emerald-600" : "text-slate-400"}`}
        title={filled ? `${label}あり` : `${label}なし`}
        aria-label={filled ? `${label}保存あり` : `${label}未入力`}
      >
        {filled ? "○" : "×"}
      </span>
      <button
        type="button"
        onClick={onEdit}
        className="inline-flex h-8 shrink-0 items-center justify-center whitespace-nowrap rounded-md border border-slate-300 px-2 text-xs text-slate-700 hover:bg-slate-50 sm:h-auto sm:py-1"
      >
        編集
      </button>
    </div>
  )
}

function today(): string {
  const d = new Date()
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, "0")
  const day = String(d.getDate()).padStart(2, "0")
  return `${y}-${m}-${day}`
}

