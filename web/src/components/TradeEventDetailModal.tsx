import { useEffect, useState } from "react"
import { Link } from "react-router-dom"
import {
  api,
  type LineChangeRow,
  type StockEntry,
  type StockExitRow,
  type StockTradeEventRow,
} from "../lib/api.ts"
import { apiErrorMessage } from "../lib/errors.ts"
import { emptyToNull, parseOptionalInt, toDateInputValue } from "../lib/stockFormUtils.ts"
import { Modal, FormError, FieldLabel, FormActions } from "./Modal.tsx"

type Props = {
  row: StockTradeEventRow
  initialEditing?: boolean
  onClose: () => void
  onSaved: () => void
}

type Loaded =
  | { kind: "entry"; data: StockEntry }
  | { kind: "exit"; data: StockExitRow }
  | { kind: "line_change"; data: LineChangeRow }

function kindLabel(kind: StockTradeEventRow["kind"]) {
  if (kind === "entry") return "エントリー"
  if (kind === "exit") return "イグジット"
  return "ライン変更"
}

export function TradeEventDetailModal({ row, initialEditing = false, onClose, onSaved }: Props) {
  const [editing, setEditing] = useState(initialEditing)
  const [loading, setLoading] = useState(true)
  const [err, setErr] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)
  const [loaded, setLoaded] = useState<Loaded | null>(null)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    setErr(null)
    void (async () => {
      try {
        if (row.kind === "entry") {
          const data = await api.entry(row.id)
          if (!cancelled) setLoaded({ kind: "entry", data })
        } else if (row.kind === "exit") {
          const data = await api.stockExit(row.id)
          if (!cancelled) setLoaded({ kind: "exit", data })
        } else {
          const data = await api.lineChange(row.id)
          if (!cancelled) setLoaded({ kind: "line_change", data })
        }
      } catch (e) {
        if (!cancelled) setErr(apiErrorMessage(e))
      } finally {
        if (!cancelled) setLoading(false)
      }
    })()
    return () => {
      cancelled = true
    }
  }, [row.kind, row.id])

  useEffect(() => {
    setEditing(initialEditing)
  }, [row.kind, row.id, initialEditing])

  const del = async () => {
    if (!window.confirm("削除しますか？")) return
    setSaving(true)
    setErr(null)
    try {
      if (row.kind === "entry") await api.deleteEntry(row.id)
      else if (row.kind === "exit") await api.deleteStockExit(row.id)
      else await api.deleteLineChange(row.id)
      onSaved()
      onClose()
    } catch (e) {
      setErr(apiErrorMessage(e))
    } finally {
      setSaving(false)
    }
  }

  return (
    <Modal title={`${kindLabel(row.kind)} 詳細`} onClose={onClose} size="lg">
      <p className="mb-3 text-sm text-slate-600">
        <Link to={`/stocks/${row.stock.id}`} className="text-indigo-600 hover:underline">
          {row.stock.code} {row.stock.name}
        </Link>
        <span className="ml-2 text-slate-400">（{row.sort_on}）</span>
      </p>

      {loading && <p className="text-sm text-slate-500">読み込み中…</p>}
      {!loading && !loaded && err && <FormError message={err} />}

      {!loading && loaded && !editing && (
        <>
          <DetailView loaded={loaded} />
          <FormError message={err} />
          <div className="mt-4 flex flex-wrap justify-between gap-2">
            <button
              type="button"
              disabled={saving}
              onClick={() => void del()}
              className="rounded-lg border border-rose-300 px-3 py-2 text-sm text-rose-700 hover:bg-rose-50 disabled:opacity-50"
            >
              削除
            </button>
            <div className="flex gap-2">
              <button
                type="button"
                onClick={onClose}
                className="rounded-lg border border-slate-300 px-3 py-2 text-sm hover:bg-slate-50"
                disabled={saving}
              >
                閉じる
              </button>
              <button
                type="button"
                onClick={() => setEditing(true)}
                className="rounded-lg bg-indigo-600 px-3 py-2 text-sm text-white hover:bg-indigo-500"
                disabled={saving}
              >
                編集
              </button>
            </div>
          </div>
        </>
      )}

      {!loading && loaded && editing && (
        <DetailEditForm
          loaded={loaded}
          saving={saving}
          err={err}
          onCancel={() => {
            setEditing(false)
            setErr(null)
          }}
          onSave={async (payload) => {
            setSaving(true)
            setErr(null)
            try {
              if (loaded.kind === "entry") {
                await api.updateEntry(loaded.data.id, payload)
              } else if (loaded.kind === "exit") {
                await api.updateStockExit(loaded.data.id, payload)
              } else {
                await api.updateLineChange(loaded.data.id, payload)
              }
              onSaved()
              onClose()
            } catch (e) {
              setErr(apiErrorMessage(e))
            } finally {
              setSaving(false)
            }
          }}
        />
      )}
    </Modal>
  )
}

function DetailView({ loaded }: { loaded: Loaded }) {
  if (loaded.kind === "entry") {
    const e = loaded.data
    return (
      <dl className="space-y-2 text-sm">
        <DetailRow label="エントリー理由" value={e.entry_reason} multiline />
        <DetailRow label="シナリオ" value={e.scenario} multiline />
        <DetailRow label="株数" value={e.shares != null ? String(e.shares) : null} />
        <DetailRow label="予定価格" value={e.expected_price} />
        <DetailRow label="約定価格" value={e.actual_price} />
        <DetailRow label="約定日" value={toDateInputValue(e.traded_at) || "未約定"} />
        <DetailRow label="メモ" value={e.memo} multiline />
      </dl>
    )
  }
  if (loaded.kind === "exit") {
    const x = loaded.data
    return (
      <dl className="space-y-2 text-sm">
        <DetailRow label="イグジット理由" value={x.exit_reason} multiline />
        <DetailRow label="株数" value={x.shares != null ? String(x.shares) : null} />
        <DetailRow label="予定価格" value={x.expected_price} />
        <DetailRow label="約定価格" value={x.actual_price} />
        <DetailRow label="約定日" value={toDateInputValue(x.traded_at) || "未約定"} />
        <DetailRow label="レビュー" value={x.review_result} />
        <DetailRow label="外れた点" value={x.review_missed} multiline />
        <DetailRow label="学び" value={x.review_learning} multiline />
        <DetailRow label="メモ" value={x.memo} multiline />
      </dl>
    )
  }
  const l = loaded.data
  return (
    <dl className="space-y-2 text-sm">
      <DetailRow label="変更日" value={toDateInputValue(l.changed_on)} />
      <DetailRow label="損切り" value={l.stop_loss} />
      <DetailRow label="目標株価" value={l.target_price} />
      <DetailRow label="理由" value={l.reason} multiline />
    </dl>
  )
}

function DetailRow({
  label,
  value,
  multiline,
}: {
  label: string
  value: string | null | undefined
  multiline?: boolean
}) {
  const display = value?.trim() ? value : "—"
  return (
    <div className="grid gap-1 sm:grid-cols-[7rem_1fr]">
      <dt className="text-slate-500">{label}</dt>
      <dd className={multiline ? "whitespace-pre-wrap text-slate-800" : "text-slate-800"}>{display}</dd>
    </div>
  )
}

function DetailEditForm({
  loaded,
  saving,
  err,
  onCancel,
  onSave,
}: {
  loaded: Loaded
  saving: boolean
  err: string | null
  onCancel: () => void
  onSave: (payload: Record<string, unknown>) => Promise<void>
}) {
  if (loaded.kind === "entry") {
    return (
      <EntryEditForm data={loaded.data} saving={saving} err={err} onCancel={onCancel} onSave={onSave} />
    )
  }
  if (loaded.kind === "exit") {
    return (
      <ExitEditForm data={loaded.data} saving={saving} err={err} onCancel={onCancel} onSave={onSave} />
    )
  }
  return (
    <LineEditForm data={loaded.data} saving={saving} err={err} onCancel={onCancel} onSave={onSave} />
  )
}

function EntryEditForm({
  data,
  saving,
  err,
  onCancel,
  onSave,
}: {
  data: StockEntry
  saving: boolean
  err: string | null
  onCancel: () => void
  onSave: (payload: Record<string, unknown>) => Promise<void>
}) {
  const [entryReason, setEntryReason] = useState(data.entry_reason)
  const [scenario, setScenario] = useState(data.scenario ?? "")
  const [shares, setShares] = useState(data.shares != null ? String(data.shares) : "")
  const [expectedPrice, setExpectedPrice] = useState(data.expected_price ?? "")
  const [actualPrice, setActualPrice] = useState(data.actual_price ?? "")
  const [tradedAt, setTradedAt] = useState(toDateInputValue(data.traded_at))
  const [memo, setMemo] = useState(data.memo ?? "")

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    void onSave({
      stock_id: data.stock_id,
      trade_type: data.trade_type,
      judgment_type: data.judgment_type,
      ai_script_id: data.ai_script_id,
      entry_reason: entryReason,
      scenario: emptyToNull(scenario),
      shares: parseOptionalInt(shares),
      expected_price: emptyToNull(expectedPrice),
      actual_price: emptyToNull(actualPrice),
      traded_at: emptyToNull(tradedAt),
      memo: emptyToNull(memo),
    })
  }

  return (
    <form onSubmit={submit} className="space-y-3 text-sm">
      <label className="flex flex-col gap-1">
        <FieldLabel>エントリー理由（必須）</FieldLabel>
        <textarea
          value={entryReason}
          onChange={(e) => setEntryReason(e.target.value)}
          className="min-h-20 rounded-lg border border-slate-300 px-2 py-1.5"
          required
        />
      </label>
      <label className="flex flex-col gap-1">
        <FieldLabel>シナリオ</FieldLabel>
        <textarea
          value={scenario}
          onChange={(e) => setScenario(e.target.value)}
          className="min-h-16 rounded-lg border border-slate-300 px-2 py-1.5"
        />
      </label>
      <div className="grid gap-3 sm:grid-cols-2">
        <label className="flex flex-col gap-1">
          <FieldLabel>株数</FieldLabel>
          <input
            value={shares}
            onChange={(e) => setShares(e.target.value)}
            className="rounded-lg border border-slate-300 px-2 py-1.5"
            inputMode="numeric"
          />
        </label>
        <label className="flex flex-col gap-1">
          <FieldLabel>予定価格</FieldLabel>
          <input
            value={expectedPrice}
            onChange={(e) => setExpectedPrice(e.target.value)}
            className="rounded-lg border border-slate-300 px-2 py-1.5"
          />
        </label>
        <label className="flex flex-col gap-1">
          <FieldLabel>約定価格</FieldLabel>
          <input
            value={actualPrice}
            onChange={(e) => setActualPrice(e.target.value)}
            className="rounded-lg border border-slate-300 px-2 py-1.5"
          />
        </label>
        <label className="flex flex-col gap-1">
          <FieldLabel>約定日（空=未約定）</FieldLabel>
          <input
            type="date"
            value={tradedAt}
            onChange={(e) => setTradedAt(e.target.value)}
            className="rounded-lg border border-slate-300 px-2 py-1.5"
          />
        </label>
      </div>
      <label className="flex flex-col gap-1">
        <FieldLabel>メモ</FieldLabel>
        <textarea
          value={memo}
          onChange={(e) => setMemo(e.target.value)}
          className="min-h-16 rounded-lg border border-slate-300 px-2 py-1.5"
        />
      </label>
      <FormError message={err} />
      <FormActions onCancel={onCancel} submitting={saving} />
    </form>
  )
}

function ExitEditForm({
  data,
  saving,
  err,
  onCancel,
  onSave,
}: {
  data: StockExitRow
  saving: boolean
  err: string | null
  onCancel: () => void
  onSave: (payload: Record<string, unknown>) => Promise<void>
}) {
  const [exitReason, setExitReason] = useState(data.exit_reason)
  const [shares, setShares] = useState(data.shares != null ? String(data.shares) : "")
  const [expectedPrice, setExpectedPrice] = useState(data.expected_price ?? "")
  const [actualPrice, setActualPrice] = useState(data.actual_price ?? "")
  const [tradedAt, setTradedAt] = useState(toDateInputValue(data.traded_at))
  const [reviewResult, setReviewResult] = useState(data.review_result ?? "")
  const [reviewMissed, setReviewMissed] = useState(data.review_missed ?? "")
  const [reviewLearning, setReviewLearning] = useState(data.review_learning ?? "")
  const [memo, setMemo] = useState(data.memo ?? "")

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    void onSave({
      stock_id: data.stock_id,
      trade_type: data.trade_type,
      judgment_type: data.judgment_type,
      ai_script_id: data.ai_script_id,
      exit_reason: exitReason,
      shares: parseOptionalInt(shares),
      expected_price: emptyToNull(expectedPrice),
      actual_price: emptyToNull(actualPrice),
      traded_at: emptyToNull(tradedAt),
      review_result: emptyToNull(reviewResult),
      review_missed: emptyToNull(reviewMissed),
      review_learning: emptyToNull(reviewLearning),
      memo: emptyToNull(memo),
    })
  }

  return (
    <form onSubmit={submit} className="space-y-3 text-sm">
      <label className="flex flex-col gap-1">
        <FieldLabel>イグジット理由（必須）</FieldLabel>
        <textarea
          value={exitReason}
          onChange={(e) => setExitReason(e.target.value)}
          className="min-h-20 rounded-lg border border-slate-300 px-2 py-1.5"
          required
        />
      </label>
      <div className="grid gap-3 sm:grid-cols-2">
        <label className="flex flex-col gap-1">
          <FieldLabel>株数</FieldLabel>
          <input
            value={shares}
            onChange={(e) => setShares(e.target.value)}
            className="rounded-lg border border-slate-300 px-2 py-1.5"
          />
        </label>
        <label className="flex flex-col gap-1">
          <FieldLabel>予定価格</FieldLabel>
          <input
            value={expectedPrice}
            onChange={(e) => setExpectedPrice(e.target.value)}
            className="rounded-lg border border-slate-300 px-2 py-1.5"
          />
        </label>
        <label className="flex flex-col gap-1">
          <FieldLabel>約定価格</FieldLabel>
          <input
            value={actualPrice}
            onChange={(e) => setActualPrice(e.target.value)}
            className="rounded-lg border border-slate-300 px-2 py-1.5"
          />
        </label>
        <label className="flex flex-col gap-1">
          <FieldLabel>約定日（空=未約定）</FieldLabel>
          <input
            type="date"
            value={tradedAt}
            onChange={(e) => setTradedAt(e.target.value)}
            className="rounded-lg border border-slate-300 px-2 py-1.5"
          />
        </label>
      </div>
      <label className="flex flex-col gap-1">
        <FieldLabel>レビュー</FieldLabel>
        <select
          value={reviewResult}
          onChange={(e) => setReviewResult(e.target.value)}
          className="rounded-lg border border-slate-300 px-2 py-1.5"
        >
          <option value="">—</option>
          <option value="as_planned">計画どおり</option>
          <option value="missed">外れた</option>
          <option value="partial">一部のみ</option>
        </select>
      </label>
      <label className="flex flex-col gap-1">
        <FieldLabel>外れた点</FieldLabel>
        <textarea
          value={reviewMissed}
          onChange={(e) => setReviewMissed(e.target.value)}
          className="min-h-16 rounded-lg border border-slate-300 px-2 py-1.5"
        />
      </label>
      <label className="flex flex-col gap-1">
        <FieldLabel>学び</FieldLabel>
        <textarea
          value={reviewLearning}
          onChange={(e) => setReviewLearning(e.target.value)}
          className="min-h-16 rounded-lg border border-slate-300 px-2 py-1.5"
        />
      </label>
      <label className="flex flex-col gap-1">
        <FieldLabel>メモ</FieldLabel>
        <textarea
          value={memo}
          onChange={(e) => setMemo(e.target.value)}
          className="min-h-16 rounded-lg border border-slate-300 px-2 py-1.5"
        />
      </label>
      <FormError message={err} />
      <FormActions onCancel={onCancel} submitting={saving} />
    </form>
  )
}

function LineEditForm({
  data,
  saving,
  err,
  onCancel,
  onSave,
}: {
  data: LineChangeRow
  saving: boolean
  err: string | null
  onCancel: () => void
  onSave: (payload: Record<string, unknown>) => Promise<void>
}) {
  const [changedOn, setChangedOn] = useState(toDateInputValue(data.changed_on))
  const [stopLoss, setStopLoss] = useState(data.stop_loss ?? "")
  const [targetPrice, setTargetPrice] = useState(data.target_price ?? "")
  const [reason, setReason] = useState(data.reason ?? "")

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    void onSave({
      stock_id: data.stock_id,
      trade_type: data.trade_type,
      judgment_type: data.judgment_type,
      ai_script_id: data.ai_script_id,
      changed_on: changedOn,
      stop_loss: emptyToNull(stopLoss),
      target_price: emptyToNull(targetPrice),
      reason: emptyToNull(reason),
    })
  }

  return (
    <form onSubmit={submit} className="space-y-3 text-sm">
      <label className="flex flex-col gap-1">
        <FieldLabel>変更日</FieldLabel>
        <input
          type="date"
          value={changedOn}
          onChange={(e) => setChangedOn(e.target.value)}
          className="rounded-lg border border-slate-300 px-2 py-1.5"
          required
        />
      </label>
      <div className="grid gap-3 sm:grid-cols-2">
        <label className="flex flex-col gap-1">
          <FieldLabel>損切り</FieldLabel>
          <input
            value={stopLoss}
            onChange={(e) => setStopLoss(e.target.value)}
            className="rounded-lg border border-slate-300 px-2 py-1.5"
          />
        </label>
        <label className="flex flex-col gap-1">
          <FieldLabel>目標株価</FieldLabel>
          <input
            value={targetPrice}
            onChange={(e) => setTargetPrice(e.target.value)}
            className="rounded-lg border border-slate-300 px-2 py-1.5"
          />
        </label>
      </div>
      <label className="flex flex-col gap-1">
        <FieldLabel>理由</FieldLabel>
        <textarea
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          className="min-h-16 rounded-lg border border-slate-300 px-2 py-1.5"
        />
      </label>
      <FormError message={err} />
      <FormActions onCancel={onCancel} submitting={saving} />
    </form>
  )
}
