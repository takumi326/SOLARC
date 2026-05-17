import { useCallback, useMemo, useState } from "react"
import { Link } from "react-router-dom"
import {
  api,
  type StockTradeEventRow,
  type StockTradeEventsQuery,
  type TradeType,
  type JudgmentType,
} from "../lib/api.ts"
import { useFetch } from "../lib/useFetch.ts"
import { deleteTradeEvent } from "../lib/stockTradeActions.ts"
import { TradeEventDetailModal } from "../components/TradeEventDetailModal.tsx"
import { RowActionButtons } from "../components/RowActionButtons.tsx"

export type StockTradesMode = "real" | "virtual-human" | "virtual-ai"

const MODE_CONFIG: Record<
  StockTradesMode,
  { title: string; trade_type: TradeType; judgment_type: JudgmentType; scriptFilter: boolean }
> = {
  real: { title: "実取引一覧", trade_type: "real", judgment_type: "human", scriptFilter: false },
  "virtual-human": { title: "仮想取引一覧（人間）", trade_type: "virtual", judgment_type: "human", scriptFilter: false },
  "virtual-ai": { title: "仮想取引一覧（AI）", trade_type: "virtual", judgment_type: "ai", scriptFilter: true },
}

type Tab = "all" | "entry" | "exit"

export function StockTradesPage({ mode }: { mode: StockTradesMode }) {
  const cfg = MODE_CONFIG[mode]
  const [tab, setTab] = useState<Tab>("all")
  const [settled, setSettled] = useState<"all" | "yes" | "no">("all")
  const [from, setFrom] = useState("")
  const [to, setTo] = useState("")
  const [aiScriptId, setAiScriptId] = useState<string>("")

  const scriptsLoader = useCallback(() => (cfg.scriptFilter ? api.aiScripts() : Promise.resolve([])), [cfg.scriptFilter])
  const scriptsResult = useFetch(scriptsLoader)

  const query = useMemo((): StockTradeEventsQuery => {
    const qv: StockTradeEventsQuery = {
      trade_type: cfg.trade_type,
      judgment_type: cfg.judgment_type,
      event_kind: tab,
      settled: settled === "all" ? undefined : settled,
      from: from.trim() || undefined,
      to: to.trim() || undefined,
    }
    if (cfg.scriptFilter && aiScriptId !== "") {
      qv.ai_script_id = Number(aiScriptId)
    }
    return qv
  }, [cfg, tab, settled, from, to, aiScriptId])

  const eventsLoader = useCallback(() => api.stockTradeEvents(query), [query])
  const eventsResult = useFetch(eventsLoader)

  const [modal, setModal] = useState<null | { type: "detail"; row: StockTradeEventRow; initialEditing?: boolean }>(null)

  if (scriptsResult.status === "loading" && cfg.scriptFilter) {
    return <p className="text-slate-600">読み込み中…</p>
  }

  return (
    <div className="space-y-4">
      <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <h2 className="mb-3 text-xl font-bold">{cfg.title}</h2>
        <div className="mb-3 flex flex-wrap gap-2">
          {(
            [
              ["all", "全部"],
              ["entry", "エントリ"],
              ["exit", "イグジット"],
            ] as const
          ).map(([id, label]) => (
            <button
              key={id}
              type="button"
              onClick={() => setTab(id)}
              className={`rounded-full px-3 py-1.5 text-sm ${
                tab === id ? "bg-indigo-600 text-white" : "bg-slate-100 text-slate-600 hover:bg-slate-200"
              }`}
            >
              {label}
            </button>
          ))}
        </div>
        <div className="mb-4 flex flex-wrap items-end gap-3">
          <label className="flex flex-col gap-1 text-sm">
            <span className="text-slate-600">約定</span>
            <select
              value={settled}
              onChange={(e) => setSettled(e.target.value as "all" | "yes" | "no")}
              className="rounded-lg border border-slate-300 px-2 py-1.5"
            >
              <option value="all">すべて</option>
              <option value="yes">約定済みのみ</option>
              <option value="no">未約定のみ</option>
            </select>
          </label>
          <label className="flex flex-col gap-1 text-sm">
            <span className="text-slate-600">期間 from</span>
            <input type="date" value={from} onChange={(e) => setFrom(e.target.value)} className="rounded-lg border border-slate-300 px-2 py-1.5" />
          </label>
          <label className="flex flex-col gap-1 text-sm">
            <span className="text-slate-600">to</span>
            <input type="date" value={to} onChange={(e) => setTo(e.target.value)} className="rounded-lg border border-slate-300 px-2 py-1.5" />
          </label>
          {cfg.scriptFilter && scriptsResult.status === "success" && (
            <label className="flex flex-col gap-1 text-sm">
              <span className="text-slate-600">AI スクリプト</span>
              <select
                value={aiScriptId}
                onChange={(e) => setAiScriptId(e.target.value)}
                className="min-w-[10rem] rounded-lg border border-slate-300 px-2 py-1.5"
              >
                <option value="">全バージョン</option>
                {scriptsResult.data.map((s) => (
                  <option key={s.id} value={String(s.id)}>
                    {s.version_name}
                  </option>
                ))}
              </select>
            </label>
          )}
        </div>
        {eventsResult.status === "loading" && <p className="text-slate-600">イベントを読み込み中…</p>}
        {eventsResult.status === "error" && <p className="text-rose-600">{eventsResult.error.message}</p>}
        {eventsResult.status === "success" && (
          <>
            <p className="mb-3 text-lg font-semibold tabular-nums">
              合計損益:{" "}
              <span className={Number(eventsResult.data.total_realized_pl) >= 0 ? "text-emerald-700" : "text-rose-700"}>
                {eventsResult.data.total_realized_pl}
              </span>
            </p>
            <div className="overflow-x-auto">
              <table className="min-w-full text-left text-sm">
                <thead>
                  <tr className="border-b border-slate-200 text-slate-500">
                    <th className="py-2 pr-2">種別</th>
                    <th className="py-2 pr-2">日付</th>
                    <th className="py-2 pr-2">銘柄</th>
                    <th className="py-2 pr-2">概要</th>
                    <th className="py-2 pr-2">操作</th>
                  </tr>
                </thead>
                <tbody>
                  {eventsResult.data.rows.map((row) => (
                    <tr key={`${row.kind}-${row.id}`} className="border-b border-slate-100">
                      <td className="py-2 pr-2">{eventKindLabel(row.kind)}</td>
                      <td className="py-2 pr-2 tabular-nums">{row.sort_on}</td>
                      <td className="py-2 pr-2">
                        <Link to={`/stocks/${row.stock.id}`} className="text-indigo-600 hover:underline">
                          {row.stock.name}
                        </Link>
                      </td>
                      <td className="max-w-md truncate py-2 pr-2 text-slate-700">{eventSummary(row)}</td>
                      <td className="py-2 pr-2">
                        <RowActionButtons
                          onDetail={() => setModal({ type: "detail", row, initialEditing: false })}
                          onEdit={() => setModal({ type: "detail", row, initialEditing: true })}
                          onDelete={() => void deleteTradeEvent(row, () => eventsResult.refetch())}
                        />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {eventsResult.data.rows.length === 0 && <p className="py-6 text-center text-slate-500">データがありません</p>}
            </div>
          </>
        )}
      </section>

      {modal?.type === "detail" && (
        <TradeEventDetailModal
          row={modal.row}
          initialEditing={modal.initialEditing}
          onClose={() => setModal(null)}
          onSaved={() => eventsResult.refetch()}
        />
      )}
    </div>
  )
}

function eventKindLabel(k: StockTradeEventRow["kind"]) {
  if (k === "entry") return "エントリ"
  if (k === "exit") return "イグジット"
  return "ライン"
}

function eventSummary(row: StockTradeEventRow) {
  if (row.kind === "entry") return row.entry_reason ?? ""
  if (row.kind === "exit") return row.exit_reason ?? ""
  return row.reason ?? ""
}
