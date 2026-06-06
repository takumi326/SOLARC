import { useState } from "react"
import { api } from "../lib/api.ts"
import { apiErrorMessage } from "../lib/errors.ts"
import { emptyToNull } from "../lib/stockFormUtils.ts"
import type { TradeAxesConfig } from "../lib/stockTradeAxes.ts"
import { Modal, FormError, FieldLabel, FormActions } from "./Modal.tsx"
import { StockPicker } from "./StockPicker.tsx"

type ModalBaseProps = {
  cfg: TradeAxesConfig
  fixedStockId?: number
  stockLabel?: string
  onClose: () => void
  onSaved: () => void
}

function resolveStockId(stockId: string, fixedStockId?: number) {
  if (fixedStockId != null) return fixedStockId
  const sid = Number(stockId)
  if (!Number.isFinite(sid)) throw new Error("銘柄を選択してください")
  return sid
}

function StockField({
  fixedStockId,
  stockLabel,
  value,
  onChange,
}: {
  fixedStockId?: number
  stockLabel?: string
  value: string
  onChange: (v: string) => void
}) {
  if (fixedStockId != null) {
    return (
      <div className="rounded-lg bg-slate-50 px-3 py-2 text-slate-800">
        <span className="text-xs text-slate-500">銘柄</span>
        <p className="font-medium">{stockLabel ?? `ID ${fixedStockId}`}</p>
      </div>
    )
  }
  return (
    <label className="flex flex-col gap-1">
      <FieldLabel>銘柄</FieldLabel>
      <StockPicker value={value} onChange={onChange} required />
    </label>
  )
}

export function QuickEntryModal(props: ModalBaseProps) {
  const { cfg, fixedStockId, stockLabel, onClose, onSaved } = props
  const [stockId, setStockId] = useState(fixedStockId != null ? String(fixedStockId) : "")
  const [entryReason, setEntryReason] = useState("")
  const [scenario, setScenario] = useState("")
  const [memo, setMemo] = useState("")
  const [shares, setShares] = useState("")
  const [expectedPrice, setExpectedPrice] = useState("")
  const [actualPrice, setActualPrice] = useState("")
  const [tradedAt, setTradedAt] = useState("")
  const [stopLoss, setStopLoss] = useState("")
  const [targetPrice, setTargetPrice] = useState("")
  const [err, setErr] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  const submit = async (e: React.FormEvent) => {
    e.preventDefault()
    setErr(null)
    setSaving(true)
    try {
      const sid = resolveStockId(stockId, fixedStockId)
      const body: Record<string, unknown> = {
        stock_id: sid,
        trade_type: cfg.trade_type,
        judgment_type: cfg.judgment_type,
        entry_reason: entryReason,
        scenario: emptyToNull(scenario),
        memo: emptyToNull(memo),
        shares: shares ? Number(shares) : null,
        expected_price: emptyToNull(expectedPrice),
        actual_price: emptyToNull(actualPrice),
        traded_at: emptyToNull(tradedAt),
      }
      if (stopLoss || targetPrice) {
        body.initial_line = { stop_loss: stopLoss || null, target_price: targetPrice || null, reason: null }
      }
      await api.createEntry(body)
      onSaved()
    } catch (e) {
      setErr(apiErrorMessage(e))
    } finally {
      setSaving(false)
    }
  }

  return (
    <Modal title="エントリー（買い）を記録" onClose={onClose} size="lg">
      <form onSubmit={(e) => void submit(e)} className="space-y-3 text-sm">
        <StockField fixedStockId={fixedStockId} stockLabel={stockLabel} value={stockId} onChange={setStockId} />
        <label className="flex flex-col gap-1">
          <FieldLabel>エントリー理由（必須）</FieldLabel>
          <textarea value={entryReason} onChange={(e) => setEntryReason(e.target.value)} className="min-h-20 rounded-lg border border-slate-300 px-2 py-1.5" required />
        </label>
        <label className="flex flex-col gap-1">
          <FieldLabel>シナリオ</FieldLabel>
          <textarea value={scenario} onChange={(e) => setScenario(e.target.value)} className="min-h-16 rounded-lg border border-slate-300 px-2 py-1.5" />
        </label>
        <div className="grid gap-3 sm:grid-cols-2">
          <label className="flex flex-col gap-1">
            <FieldLabel>株数</FieldLabel>
            <input value={shares} onChange={(e) => setShares(e.target.value)} className="rounded-lg border border-slate-300 px-2 py-1.5" inputMode="numeric" />
          </label>
          <label className="flex flex-col gap-1">
            <FieldLabel>予定価格</FieldLabel>
            <input value={expectedPrice} onChange={(e) => setExpectedPrice(e.target.value)} className="rounded-lg border border-slate-300 px-2 py-1.5" />
          </label>
          <label className="flex flex-col gap-1">
            <FieldLabel>約定価格</FieldLabel>
            <input value={actualPrice} onChange={(e) => setActualPrice(e.target.value)} className="rounded-lg border border-slate-300 px-2 py-1.5" />
          </label>
          <label className="flex flex-col gap-1">
            <FieldLabel>約定日（空=未約定）</FieldLabel>
            <input type="date" value={tradedAt} onChange={(e) => setTradedAt(e.target.value)} className="rounded-lg border border-slate-300 px-2 py-1.5" />
          </label>
        </div>
        <div className="grid gap-3 sm:grid-cols-2">
          <label className="flex flex-col gap-1">
            <FieldLabel>損切り（初期ライン）</FieldLabel>
            <input value={stopLoss} onChange={(e) => setStopLoss(e.target.value)} className="rounded-lg border border-slate-300 px-2 py-1.5" />
          </label>
          <label className="flex flex-col gap-1">
            <FieldLabel>目標株価（初期ライン）</FieldLabel>
            <input value={targetPrice} onChange={(e) => setTargetPrice(e.target.value)} className="rounded-lg border border-slate-300 px-2 py-1.5" />
          </label>
        </div>
        <label className="flex flex-col gap-1">
          <FieldLabel>メモ</FieldLabel>
          <textarea value={memo} onChange={(e) => setMemo(e.target.value)} className="min-h-16 rounded-lg border border-slate-300 px-2 py-1.5" />
        </label>
        <FormError message={err} />
        <FormActions onCancel={onClose} submitting={saving} />
      </form>
    </Modal>
  )
}

export function QuickExitModal(props: ModalBaseProps) {
  const { cfg, fixedStockId, stockLabel, onClose, onSaved } = props
  const [stockId, setStockId] = useState(fixedStockId != null ? String(fixedStockId) : "")
  const [exitReason, setExitReason] = useState("")
  const [shares, setShares] = useState("")
  const [expectedPrice, setExpectedPrice] = useState("")
  const [actualPrice, setActualPrice] = useState("")
  const [tradedAt, setTradedAt] = useState("")
  const [reviewResult, setReviewResult] = useState("")
  const [reviewMissed, setReviewMissed] = useState("")
  const [reviewLearning, setReviewLearning] = useState("")
  const [memo, setMemo] = useState("")
  const [err, setErr] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  const submit = async (e: React.FormEvent) => {
    e.preventDefault()
    setErr(null)
    setSaving(true)
    try {
      const sid = resolveStockId(stockId, fixedStockId)
      await api.createStockExit({
        stock_id: sid,
        trade_type: cfg.trade_type,
        judgment_type: cfg.judgment_type,
        exit_reason: exitReason,
        shares: shares ? Number(shares) : null,
        expected_price: emptyToNull(expectedPrice),
        actual_price: emptyToNull(actualPrice),
        traded_at: emptyToNull(tradedAt),
        review_result: emptyToNull(reviewResult),
        review_missed: emptyToNull(reviewMissed),
        review_learning: emptyToNull(reviewLearning),
        memo: emptyToNull(memo),
      })
      onSaved()
    } catch (e) {
      setErr(apiErrorMessage(e))
    } finally {
      setSaving(false)
    }
  }

  return (
    <Modal title="イグジット（売り）を記録" onClose={onClose} size="lg">
      <form onSubmit={(e) => void submit(e)} className="space-y-3 text-sm">
        <StockField fixedStockId={fixedStockId} stockLabel={stockLabel} value={stockId} onChange={setStockId} />
        <label className="flex flex-col gap-1">
          <FieldLabel>イグジット理由（必須）</FieldLabel>
          <textarea value={exitReason} onChange={(e) => setExitReason(e.target.value)} className="min-h-20 rounded-lg border border-slate-300 px-2 py-1.5" required />
        </label>
        <div className="grid gap-3 sm:grid-cols-2">
          <label className="flex flex-col gap-1">
            <FieldLabel>株数</FieldLabel>
            <input value={shares} onChange={(e) => setShares(e.target.value)} className="rounded-lg border border-slate-300 px-2 py-1.5" />
          </label>
          <label className="flex flex-col gap-1">
            <FieldLabel>予定価格</FieldLabel>
            <input value={expectedPrice} onChange={(e) => setExpectedPrice(e.target.value)} className="rounded-lg border border-slate-300 px-2 py-1.5" />
          </label>
          <label className="flex flex-col gap-1">
            <FieldLabel>約定価格</FieldLabel>
            <input value={actualPrice} onChange={(e) => setActualPrice(e.target.value)} className="rounded-lg border border-slate-300 px-2 py-1.5" />
          </label>
          <label className="flex flex-col gap-1">
            <FieldLabel>約定日（空=未約定）</FieldLabel>
            <input type="date" value={tradedAt} onChange={(e) => setTradedAt(e.target.value)} className="rounded-lg border border-slate-300 px-2 py-1.5" />
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
          <textarea value={reviewMissed} onChange={(e) => setReviewMissed(e.target.value)} className="min-h-16 rounded-lg border border-slate-300 px-2 py-1.5" />
        </label>
        <label className="flex flex-col gap-1">
          <FieldLabel>学び</FieldLabel>
          <textarea value={reviewLearning} onChange={(e) => setReviewLearning(e.target.value)} className="min-h-16 rounded-lg border border-slate-300 px-2 py-1.5" />
        </label>
        <label className="flex flex-col gap-1">
          <FieldLabel>メモ</FieldLabel>
          <textarea value={memo} onChange={(e) => setMemo(e.target.value)} className="min-h-16 rounded-lg border border-slate-300 px-2 py-1.5" />
        </label>
        <FormError message={err} />
        <FormActions onCancel={onClose} submitting={saving} />
      </form>
    </Modal>
  )
}

export function QuickLineModal(props: ModalBaseProps) {
  const { cfg, fixedStockId, stockLabel, onClose, onSaved } = props
  const [stockId, setStockId] = useState(fixedStockId != null ? String(fixedStockId) : "")
  const [changedOn, setChangedOn] = useState(() => new Date().toISOString().slice(0, 10))
  const [stopLoss, setStopLoss] = useState("")
  const [targetPrice, setTargetPrice] = useState("")
  const [reason, setReason] = useState("")
  const [err, setErr] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  const submit = async (e: React.FormEvent) => {
    e.preventDefault()
    setErr(null)
    setSaving(true)
    try {
      const sid = resolveStockId(stockId, fixedStockId)
      await api.createLineChange({
        stock_id: sid,
        trade_type: cfg.trade_type,
        judgment_type: cfg.judgment_type,
        changed_on: changedOn,
        stop_loss: stopLoss || null,
        target_price: targetPrice || null,
        reason: reason || null,
      })
      onSaved()
    } catch (e) {
      setErr(apiErrorMessage(e))
    } finally {
      setSaving(false)
    }
  }

  return (
    <Modal title="ライン変更" onClose={onClose} size="lg">
      <form onSubmit={(e) => void submit(e)} className="space-y-3 text-sm">
        <StockField fixedStockId={fixedStockId} stockLabel={stockLabel} value={stockId} onChange={setStockId} />
        <label className="flex flex-col gap-1">
          <FieldLabel>変更日</FieldLabel>
          <input type="date" value={changedOn} onChange={(e) => setChangedOn(e.target.value)} className="rounded-lg border border-slate-300 px-2 py-1.5" required />
        </label>
        <div className="grid gap-3 sm:grid-cols-2">
          <label className="flex flex-col gap-1">
            <FieldLabel>損切り</FieldLabel>
            <input value={stopLoss} onChange={(e) => setStopLoss(e.target.value)} className="rounded-lg border border-slate-300 px-2 py-1.5" />
          </label>
          <label className="flex flex-col gap-1">
            <FieldLabel>目標株価</FieldLabel>
            <input value={targetPrice} onChange={(e) => setTargetPrice(e.target.value)} className="rounded-lg border border-slate-300 px-2 py-1.5" />
          </label>
        </div>
        <label className="flex flex-col gap-1">
          <FieldLabel>理由</FieldLabel>
          <textarea value={reason} onChange={(e) => setReason(e.target.value)} className="min-h-16 rounded-lg border border-slate-300 px-2 py-1.5" />
        </label>
        <FormError message={err} />
        <FormActions onCancel={onClose} submitting={saving} />
      </form>
    </Modal>
  )
}
