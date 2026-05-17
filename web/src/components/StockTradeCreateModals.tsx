import { useState } from "react"
import { api, type AiScriptRow, type JudgmentType, type TradeType } from "../lib/api.ts"
import { apiErrorMessage } from "../lib/errors.ts"
import { Modal, FormError, FieldLabel, FormActions } from "./Modal.tsx"
import { StockPicker } from "./StockPicker.tsx"

export type TradeAxesConfig = {
  trade_type: TradeType
  judgment_type: JudgmentType
}

export type TimelineTab = "real" | "virtual-human" | "virtual-ai"

export function tradeAxesFromTimelineTab(tab: TimelineTab): TradeAxesConfig {
  if (tab === "real") return { trade_type: "real", judgment_type: "human" }
  if (tab === "virtual-human") return { trade_type: "virtual", judgment_type: "human" }
  return { trade_type: "virtual", judgment_type: "ai" }
}

export function timelineTabLabel(tab: TimelineTab): string {
  if (tab === "real") return "実取引"
  if (tab === "virtual-human") return "仮想・人間"
  return "仮想・AI"
}

export function timelineTabDescription(tab: TimelineTab): string {
  if (tab === "real") return "証券口座など実際の売買"
  if (tab === "virtual-human") return "紙トレード・検証用（自分の判断）"
  return "AI スクリプトに沿った仮想トレード"
}

type ModalBaseProps = {
  cfg: TradeAxesConfig
  aiScriptId: number | null
  scripts: AiScriptRow[]
  fixedStockId?: number
  stockLabel?: string
  onClose: () => void
  onSaved: () => void
}

function initialScriptId(aiScriptId: number | null): string {
  return aiScriptId != null ? String(aiScriptId) : ""
}

function resolveAiScriptId(cfg: TradeAxesConfig, selectedScriptId: string, scripts: AiScriptRow[]) {
  if (cfg.judgment_type !== "ai") return null
  if (scripts.length === 0) throw new Error("AI スクリプトを先に登録してください")
  const id = Number(selectedScriptId)
  if (!Number.isFinite(id) || id <= 0) throw new Error("AI スクリプトを選択してください")
  return id
}

function AiScriptField({
  scripts,
  value,
  onChange,
}: {
  scripts: AiScriptRow[]
  value: string
  onChange: (v: string) => void
}) {
  if (scripts.length === 0) {
    return <p className="text-sm text-rose-600">AI スクリプトを先に「AI スクリプト一覧」で登録してください。</p>
  }
  return (
    <label className="flex flex-col gap-1">
      <FieldLabel>AI スクリプト</FieldLabel>
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="rounded-lg border border-slate-300 px-2 py-1.5"
        required
      >
        <option value="">選択してください</option>
        {scripts.map((s) => (
          <option key={s.id} value={String(s.id)}>
            {s.version_name}
          </option>
        ))}
      </select>
    </label>
  )
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
  const { cfg, aiScriptId, scripts, fixedStockId, stockLabel, onClose, onSaved } = props
  const [selectedScriptId, setSelectedScriptId] = useState(() => initialScriptId(aiScriptId))
  const [stockId, setStockId] = useState(fixedStockId != null ? String(fixedStockId) : "")
  const [entryReason, setEntryReason] = useState("")
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
      const scriptId = resolveAiScriptId(cfg, selectedScriptId, scripts)
      const body: Record<string, unknown> = {
        stock_id: sid,
        trade_type: cfg.trade_type,
        judgment_type: cfg.judgment_type,
        ai_script_id: cfg.judgment_type === "ai" ? scriptId : null,
        entry_reason: entryReason,
        shares: shares ? Number(shares) : null,
        expected_price: expectedPrice || null,
        actual_price: actualPrice || null,
        traded_at: tradedAt || null,
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
        {cfg.judgment_type === "ai" && (
          <AiScriptField scripts={scripts} value={selectedScriptId} onChange={setSelectedScriptId} />
        )}
        <label className="flex flex-col gap-1">
          <FieldLabel>エントリー理由（必須）</FieldLabel>
          <textarea value={entryReason} onChange={(e) => setEntryReason(e.target.value)} className="min-h-20 rounded-lg border border-slate-300 px-2 py-1.5" required />
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
            <FieldLabel>約定日</FieldLabel>
            <input type="date" value={tradedAt} onChange={(e) => setTradedAt(e.target.value)} className="rounded-lg border border-slate-300 px-2 py-1.5" />
          </label>
        </div>
        <div className="grid gap-3 sm:grid-cols-2">
          <label className="flex flex-col gap-1">
            <FieldLabel>損切りライン</FieldLabel>
            <input value={stopLoss} onChange={(e) => setStopLoss(e.target.value)} className="rounded-lg border border-slate-300 px-2 py-1.5" />
          </label>
          <label className="flex flex-col gap-1">
            <FieldLabel>目標価格</FieldLabel>
            <input value={targetPrice} onChange={(e) => setTargetPrice(e.target.value)} className="rounded-lg border border-slate-300 px-2 py-1.5" />
          </label>
        </div>
        <FormError message={err} />
        <FormActions onCancel={onClose} submitting={saving} />
      </form>
    </Modal>
  )
}

export function QuickExitModal(props: ModalBaseProps) {
  const { cfg, aiScriptId, scripts, fixedStockId, stockLabel, onClose, onSaved } = props
  const [selectedScriptId, setSelectedScriptId] = useState(() => initialScriptId(aiScriptId))
  const [stockId, setStockId] = useState(fixedStockId != null ? String(fixedStockId) : "")
  const [exitReason, setExitReason] = useState("")
  const [shares, setShares] = useState("")
  const [expectedPrice, setExpectedPrice] = useState("")
  const [actualPrice, setActualPrice] = useState("")
  const [tradedAt, setTradedAt] = useState("")
  const [err, setErr] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  const submit = async (e: React.FormEvent) => {
    e.preventDefault()
    setErr(null)
    setSaving(true)
    try {
      const sid = resolveStockId(stockId, fixedStockId)
      const scriptId = resolveAiScriptId(cfg, selectedScriptId, scripts)
      await api.createStockExit({
        stock_id: sid,
        trade_type: cfg.trade_type,
        judgment_type: cfg.judgment_type,
        ai_script_id: cfg.judgment_type === "ai" ? scriptId : null,
        exit_reason: exitReason,
        shares: shares ? Number(shares) : null,
        expected_price: expectedPrice || null,
        actual_price: actualPrice || null,
        traded_at: tradedAt || null,
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
        {cfg.judgment_type === "ai" && (
          <AiScriptField scripts={scripts} value={selectedScriptId} onChange={setSelectedScriptId} />
        )}
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
            <FieldLabel>約定日</FieldLabel>
            <input type="date" value={tradedAt} onChange={(e) => setTradedAt(e.target.value)} className="rounded-lg border border-slate-300 px-2 py-1.5" />
          </label>
        </div>
        <FormError message={err} />
        <FormActions onCancel={onClose} submitting={saving} />
      </form>
    </Modal>
  )
}

export function QuickLineModal(props: ModalBaseProps) {
  const { cfg, aiScriptId, scripts, fixedStockId, stockLabel, onClose, onSaved } = props
  const [selectedScriptId, setSelectedScriptId] = useState(() => initialScriptId(aiScriptId))
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
      const scriptId = resolveAiScriptId(cfg, selectedScriptId, scripts)
      await api.createLineChange({
        stock_id: sid,
        trade_type: cfg.trade_type,
        judgment_type: cfg.judgment_type,
        ai_script_id: cfg.judgment_type === "ai" ? scriptId : null,
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
        {cfg.judgment_type === "ai" && (
          <AiScriptField scripts={scripts} value={selectedScriptId} onChange={setSelectedScriptId} />
        )}
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
            <FieldLabel>目標</FieldLabel>
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
