import { useCallback, useState } from "react"
import { Link, useParams } from "react-router-dom"
import {
  api,
  type AiScriptRow,
  type StockCurrentLine,
  type StockDetail,
  type StockNote,
  type StockTradeEventRow,
} from "../lib/api.ts"
import { apiErrorMessage } from "../lib/errors.ts"
import { deleteTradeEvent } from "../lib/stockTradeActions.ts"
import { useFetch } from "../lib/useFetch.ts"
import { Modal, FormError, FieldLabel, FormActions } from "../components/Modal.tsx"
import { RowActionButtons } from "../components/RowActionButtons.tsx"
import { TradeEventDetailModal } from "../components/TradeEventDetailModal.tsx"
import { QuickEntryModal, QuickExitModal, QuickLineModal } from "../components/StockTradeCreateModals.tsx"
import { tradeAxesFromTimelineTab, type TimelineTab } from "../lib/stockTradeAxes.ts"

export function StockDetailPage() {
  const { id } = useParams()
  const stockId = Number(id)
  const [tlTab, setTlTab] = useState<TimelineTab>("real")
  const [aiScriptId, setAiScriptId] = useState<string>("")

  const stockLoader = useCallback(() => {
    if (!Number.isFinite(stockId)) return Promise.reject(new Error("不正な ID"))
    return api.stock(stockId)
  }, [stockId])
  const stockResult = useFetch(stockLoader)

  const notesLoader = useCallback(() => {
    if (!Number.isFinite(stockId)) return Promise.reject(new Error("不正な ID"))
    return api.stockNotes(stockId)
  }, [stockId])
  const notesResult = useFetch(notesLoader)

  const scriptsLoader = useCallback(() => api.aiScripts(), [])
  const scriptsResult = useFetch(scriptsLoader)

  const tlQuery = useCallback(() => {
    if (!Number.isFinite(stockId)) return Promise.reject(new Error("不正な ID"))
    if (tlTab === "real") return api.stockTimeline(stockId, { trade_type: "real", judgment_type: "human" })
    if (tlTab === "virtual-human") return api.stockTimeline(stockId, { trade_type: "virtual", judgment_type: "human" })
    const sid = aiScriptId === "" ? null : Number(aiScriptId)
    return api.stockTimeline(stockId, { trade_type: "virtual", judgment_type: "ai", ai_script_id: sid ?? undefined })
  }, [stockId, tlTab, aiScriptId])
  const tlResult = useFetch(tlQuery)

  const [memoOpen, setMemoOpen] = useState(false)
  const [noteOpen, setNoteOpen] = useState<StockNote | "new" | null>(null)
  const [tradeDetail, setTradeDetail] = useState<{ row: StockTradeEventRow; initialEditing: boolean } | null>(null)
  const [tradeCreateModal, setTradeCreateModal] = useState<"entry" | "exit" | "line" | null>(null)

  if (!Number.isFinite(stockId)) {
    return <p className="text-rose-600">不正な URL です</p>
  }

  if (stockResult.status === "loading") return <p className="text-slate-600">読み込み中…</p>
  if (stockResult.status === "error") return <p className="text-rose-600">{stockResult.error.message}</p>

  const s = stockResult.data

  return (
    <div className="space-y-4">
      <div className="text-sm text-slate-500">
        <Link to="/stocks" className="text-indigo-600 hover:underline">
          株一覧
        </Link>
        {" / "}
        <span className="text-slate-800">{s.name}</span>
      </div>
      <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 className="text-xl font-bold">
              <span className="font-mono text-slate-500">{s.code}</span> {s.name}
            </h2>
            <p className="mt-1 text-sm text-slate-600">{s.industry_name}</p>
          </div>
          <a
            href={s.tradingview_url}
            target="_blank"
            rel="noreferrer"
            className="rounded-lg bg-slate-900 px-3 py-2 text-sm text-white hover:bg-slate-800"
          >
            TradingView で開く
          </a>
        </div>
        <div className="mt-4 rounded-lg bg-slate-50 p-3 text-sm">
          <div className="mb-1 flex items-center justify-between gap-2">
            <span className="font-medium text-slate-700">銘柄メモ</span>
            <button type="button" onClick={() => setMemoOpen(true)} className="text-indigo-600 hover:underline">
              編集
            </button>
          </div>
          <p className="whitespace-pre-wrap text-slate-700">{s.memo?.trim() ? s.memo : "（未入力）"}</p>
        </div>
      </section>

      <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <div className="mb-3 flex items-center justify-between gap-2">
          <h3 className="text-lg font-semibold">観察履歴</h3>
          <button
            type="button"
            onClick={() => setNoteOpen("new")}
            className="rounded-lg bg-indigo-600 px-3 py-1.5 text-sm text-white hover:bg-indigo-500"
          >
            追加
          </button>
        </div>
        {notesResult.status === "success" && (
          <ul className="space-y-2">
            {notesResult.data.map((n) => (
              <li
                key={n.id}
                className="flex items-center justify-between gap-2 rounded-lg border border-slate-100 px-3 py-2"
              >
                <p className="min-w-0 flex-1 truncate text-sm text-slate-800" title={n.note}>
                  {n.note}
                </p>
                <RowActionButtons
                  onEdit={() => setNoteOpen(n)}
                  onDelete={() => void deleteStockNote(stockId, n.id, () => notesResult.refetch())}
                />
              </li>
            ))}
            {notesResult.data.length === 0 && <p className="text-sm text-slate-500">まだありません</p>}
          </ul>
        )}
      </section>

      <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <div className="mb-3 flex flex-wrap items-center justify-between gap-3">
          <h3 className="text-lg font-semibold">取引タイムライン</h3>
          <div className="flex flex-wrap gap-2">
            <button
              type="button"
              onClick={() => setTradeCreateModal("entry")}
              className="rounded-lg bg-indigo-600 px-3 py-1.5 text-sm text-white hover:bg-indigo-500"
            >
              エントリー（買い）
            </button>
            <button
              type="button"
              onClick={() => setTradeCreateModal("exit")}
              className="rounded-lg border border-indigo-600 px-3 py-1.5 text-sm text-indigo-700 hover:bg-indigo-50"
            >
              イグジット（売り）
            </button>
            <button
              type="button"
              onClick={() => setTradeCreateModal("line")}
              className="rounded-lg border border-slate-300 px-3 py-1.5 text-sm hover:bg-slate-50"
            >
              ライン変更
            </button>
          </div>
        </div>
        <div className="mb-3 flex flex-wrap gap-2">
          {(
            [
              ["real", "実取引"],
              ["virtual-human", "仮想・人間"],
              ["virtual-ai", "仮想・AI"],
            ] as const
          ).map(([key, label]) => (
            <button
              key={key}
              type="button"
              onClick={() => setTlTab(key)}
              className={`rounded-full px-3 py-1.5 text-sm ${
                tlTab === key ? "bg-indigo-600 text-white" : "bg-slate-100 text-slate-600 hover:bg-slate-200"
              }`}
            >
              {label}
            </button>
          ))}
        </div>
        {tlTab === "virtual-ai" && scriptsResult.status === "success" && (
          <label className="mb-3 flex max-w-md flex-col gap-1 text-sm">
            <span className="text-slate-600">AI スクリプト</span>
            <select value={aiScriptId} onChange={(e) => setAiScriptId(e.target.value)} className="rounded-lg border border-slate-300 px-2 py-1.5">
              <option value="">未指定（新規記録は先頭のスクリプト）</option>
              {scriptsResult.data.map((sc) => (
                <option key={sc.id} value={String(sc.id)}>
                  {sc.version_name}
                </option>
              ))}
            </select>
          </label>
        )}
        {tlResult.status === "loading" && <p className="text-sm text-slate-600">読み込み中…</p>}
        {tlResult.status === "error" && <p className="text-sm text-rose-600">{tlResult.error.message}</p>}
        {tlResult.status === "success" && <CurrentLinePanel line={tlResult.data.current_line} />}
        {tlResult.status === "success" && (
          <ul className="max-h-96 space-y-2 overflow-y-auto text-sm">
            {tlResult.data.rows.map((r) => {
              const row = withStockContext(r, s)
              return (
                <li
                  key={`${r.kind}-${r.id}`}
                  className="flex items-center justify-between gap-2 rounded-lg border border-slate-100 px-3 py-2"
                >
                  <div className="min-w-0 flex-1">
                    <span className="text-slate-500">{r.sort_on}</span>{" "}
                    <span className="font-medium">
                      {r.kind === "entry" ? "エントリー（買い）" : r.kind === "exit" ? "イグジット（売り）" : "ライン変更"}
                    </span>
                    <span className="ml-2 text-slate-700">{timelineSummary(r)}</span>
                  </div>
                  <RowActionButtons
                    onDetail={() => setTradeDetail({ row, initialEditing: false })}
                    onEdit={() => setTradeDetail({ row, initialEditing: true })}
                    onDelete={() =>
                      void deleteTradeEvent(row, () => {
                        void tlResult.refetch()
                        void stockResult.refetch()
                      })
                    }
                  />
                </li>
              )
            })}
            {tlResult.data.rows.length === 0 && <p className="text-slate-500">イベントがありません</p>}
          </ul>
        )}
      </section>

      {memoOpen && (
        <MemoEditModal
          stock={s}
          onClose={() => setMemoOpen(false)}
          onSaved={() => {
            setMemoOpen(false)
            stockResult.refetch()
          }}
        />
      )}
      {noteOpen && (
        <StockNoteModal
          stockId={stockId}
          existing={noteOpen === "new" ? null : noteOpen}
          onClose={() => setNoteOpen(null)}
          onSaved={() => {
            setNoteOpen(null)
            notesResult.refetch()
          }}
        />
      )}
      {tradeDetail && (
        <TradeEventDetailModal
          row={tradeDetail.row}
          initialEditing={tradeDetail.initialEditing}
          onClose={() => setTradeDetail(null)}
          onSaved={() => {
            setTradeDetail(null)
            void tlResult.refetch()
            void stockResult.refetch()
          }}
        />
      )}
      {tradeCreateModal && (
        <StockTradeCreateModal
          kind={tradeCreateModal}
          stockId={stockId}
          stockLabel={`${s.code} ${s.name}`}
          tlTab={tlTab}
          aiScriptId={aiScriptId === "" ? null : Number(aiScriptId)}
          scripts={scriptsResult.status === "success" ? scriptsResult.data : []}
          onClose={() => setTradeCreateModal(null)}
          onSaved={() => {
            setTradeCreateModal(null)
            void tlResult.refetch()
            void stockResult.refetch()
          }}
        />
      )}
    </div>
  )
}

function StockTradeCreateModal({
  kind,
  stockId,
  stockLabel,
  tlTab,
  aiScriptId,
  scripts,
  onClose,
  onSaved,
}: {
  kind: "entry" | "exit" | "line"
  stockId: number
  stockLabel: string
  tlTab: TimelineTab
  aiScriptId: number | null
  scripts: AiScriptRow[]
  onClose: () => void
  onSaved: () => void
}) {
  const cfg = tradeAxesFromTimelineTab(tlTab)
  const props = {
    cfg,
    aiScriptId,
    scripts,
    fixedStockId: stockId,
    stockLabel,
    onClose,
    onSaved,
  }
  if (kind === "entry") return <QuickEntryModal {...props} />
  if (kind === "exit") return <QuickExitModal {...props} />
  return <QuickLineModal {...props} />
}

function formatLineValue(v: string | null | undefined) {
  return v?.trim() ? v : "—"
}

function CurrentLinePanel({ line }: { line: StockCurrentLine | null }) {
  if (!line) {
    return (
      <p className="mb-3 text-sm text-slate-500">ライン未登録</p>
    )
  }
  return (
    <p className="mb-3 text-sm tabular-nums text-slate-700">
      <span className="text-slate-500">損切り</span> {formatLineValue(line.stop_loss)}
      <span className="mx-3 text-slate-300">|</span>
      <span className="text-slate-500">目標</span> {formatLineValue(line.target_price)}
    </p>
  )
}

function timelineSummary(r: StockTradeEventRow) {
  if (r.kind === "entry") return r.entry_reason ?? ""
  if (r.kind === "exit") return r.exit_reason ?? ""
  return r.reason ?? ""
}

function withStockContext(
  r: StockTradeEventRow,
  stock: { id: number; code: string; name: string },
): StockTradeEventRow {
  return { ...r, stock: r.stock ?? stock }
}

async function deleteStockNote(stockId: number, noteId: number, onDone: () => void) {
  if (!window.confirm("この観察記録を削除しますか？")) return
  try {
    await api.deleteStockNote(stockId, noteId)
    onDone()
  } catch (e) {
    window.alert(apiErrorMessage(e))
  }
}

function MemoEditModal({
  stock,
  onClose,
  onSaved,
}: {
  stock: StockDetail
  onClose: () => void
  onSaved: () => void
}) {
  const [memo, setMemo] = useState(stock.memo ?? "")
  const [err, setErr] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  const save = async (e: React.FormEvent) => {
    e.preventDefault()
    setSaving(true)
    setErr(null)
    try {
      await api.updateStock(stock.id, { memo })
      onSaved()
    } catch (e) {
      setErr(apiErrorMessage(e))
    } finally {
      setSaving(false)
    }
  }

  return (
    <Modal title="銘柄メモ" onClose={onClose} size="lg">
      <form onSubmit={(e) => void save(e)} className="space-y-3">
        <textarea value={memo} onChange={(e) => setMemo(e.target.value)} className="min-h-40 w-full rounded-lg border border-slate-300 p-2 text-sm" />
        <FormError message={err} />
        <FormActions onCancel={onClose} submitting={saving} />
      </form>
    </Modal>
  )
}

function StockNoteModal({
  stockId,
  existing,
  onClose,
  onSaved,
}: {
  stockId: number
  existing: StockNote | null
  onClose: () => void
  onSaved: () => void
}) {
  const [notedOn, setNotedOn] = useState(existing?.noted_on ?? new Date().toISOString().slice(0, 10))
  const [note, setNote] = useState(existing?.note ?? "")
  const [err, setErr] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  const save = async (e: React.FormEvent) => {
    e.preventDefault()
    setSaving(true)
    setErr(null)
    try {
      if (existing) await api.updateStockNote(stockId, existing.id, { noted_on: notedOn, note })
      else await api.createStockNote(stockId, { noted_on: notedOn, note })
      onSaved()
    } catch (e) {
      setErr(apiErrorMessage(e))
    } finally {
      setSaving(false)
    }
  }

  const del = async () => {
    if (!existing) return
    if (!window.confirm("この観察記録を削除しますか？")) return
    setSaving(true)
    setErr(null)
    try {
      await api.deleteStockNote(stockId, existing.id)
      onSaved()
    } catch (e) {
      setErr(apiErrorMessage(e))
    } finally {
      setSaving(false)
    }
  }

  return (
    <Modal title={existing ? "観察メモを編集" : "観察メモを追加"} onClose={onClose}>
      <form onSubmit={(e) => void save(e)} className="space-y-3 text-sm">
        <label className="flex flex-col gap-1">
          <FieldLabel>記録日</FieldLabel>
          <input type="date" value={notedOn} onChange={(e) => setNotedOn(e.target.value)} className="rounded-lg border border-slate-300 px-2 py-1.5" required />
        </label>
        <label className="flex flex-col gap-1">
          <FieldLabel>内容</FieldLabel>
          <textarea value={note} onChange={(e) => setNote(e.target.value)} className="min-h-32 rounded-lg border border-slate-300 px-2 py-1.5" required />
        </label>
        <FormError message={err} />
        <div className="flex flex-wrap items-center justify-between gap-2">
          {existing ? (
            <button
              type="button"
              onClick={() => void del()}
              disabled={saving}
              className="text-sm text-rose-600 hover:underline disabled:opacity-50"
            >
              削除
            </button>
          ) : (
            <span />
          )}
          <FormActions onCancel={onClose} submitting={saving} />
        </div>
      </form>
    </Modal>
  )
}
