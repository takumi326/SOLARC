import { useCallback, useRef, useState } from "react"
import { Link } from "react-router-dom"
import { api, type StockListRow } from "../lib/api.ts"
import { apiErrorMessage } from "../lib/errors.ts"
import { useFetch } from "../lib/useFetch.ts"

const SCOPE_STORAGE_KEY = "stocks-list-scope"

function readScopeAll(): boolean {
  try {
    return sessionStorage.getItem(SCOPE_STORAGE_KEY) === "all"
  } catch {
    return false
  }
}

function writeScopeAll(all: boolean) {
  try {
    sessionStorage.setItem(SCOPE_STORAGE_KEY, all ? "all" : "holdings")
  } catch {
    /* ignore */
  }
}

export function StocksListPage() {
  const [scopeAll, setScopeAll] = useState(readScopeAll)
  const [q, setQ] = useState("")
  const [qDraft, setQDraft] = useState("")
  const fileRef = useRef<HTMLInputElement>(null)
  const [importMsg, setImportMsg] = useState<string | null>(null)
  const [importErr, setImportErr] = useState<string | null>(null)
  const [importing, setImporting] = useState(false)

  const loader = useCallback(
    () => api.stocks({ scope: scopeAll ? "all" : undefined, q: q || undefined }),
    [scopeAll, q],
  )
  const result = useFetch(loader)

  const runImport = async (file: File | undefined) => {
    if (!file) return
    setImportErr(null)
    setImportMsg(null)
    setImporting(true)
    try {
      const r = await api.importStocksCsv(file)
      setScopeAll(true)
      writeScopeAll(true)
      setImportMsg(
        `読み込んで登録しました。新規業種 ${r.created_industries} / 新規銘柄 ${r.created_stocks} / 更新 ${r.updated_stocks} / スキップ ${r.skipped_rows}`,
      )
    } catch (e) {
      setImportErr(apiErrorMessage(e))
    } finally {
      setImporting(false)
      if (fileRef.current) fileRef.current.value = ""
    }
  }

  if (result.status === "loading") {
    return <p className="text-slate-600">読み込み中…</p>
  }
  if (result.status === "error") {
    return <p className="text-rose-600">{result.error.message}</p>
  }

  const rows = result.data

  return (
    <div className="space-y-4">
      <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <h2 className="mb-3 text-xl font-bold">株一覧</h2>
        <p className="mb-4 text-sm text-slate-600">
          CSV を選ぶと銘柄マスタへ読み込んで登録します（列: 銘柄名・コード・業種。UTF-8 / Shift_JIS どちらも可）。
          一覧の初期表示は実取引の保有銘柄のみです。CSV 登録直後は全銘柄表示に切り替わります。
        </p>
        <div className="mb-4 flex flex-wrap items-end gap-3">
          <label className="flex flex-col gap-1 text-sm">
            <span className="text-slate-600">表示</span>
            <select
              value={scopeAll ? "all" : "holdings"}
              onChange={(e) => {
                const all = e.target.value === "all"
                setScopeAll(all)
                writeScopeAll(all)
              }}
              className="rounded-lg border border-slate-300 px-2 py-1.5"
            >
              <option value="holdings">保有のみ（実取引）</option>
              <option value="all">全銘柄</option>
            </select>
          </label>
          <form
            className="flex flex-wrap items-end gap-2"
            onSubmit={(e) => {
              e.preventDefault()
              setQ(qDraft.trim())
            }}
          >
            <label className="flex flex-col gap-1 text-sm">
              <span className="text-slate-600">検索（コード・銘柄名）</span>
              <input
                value={qDraft}
                onChange={(e) => setQDraft(e.target.value)}
                className="w-48 rounded-lg border border-slate-300 px-2 py-1.5"
                placeholder="例: 7203"
              />
            </label>
            <button
              type="submit"
              className="rounded-lg bg-slate-800 px-3 py-1.5 text-sm text-white hover:bg-slate-700"
            >
              検索
            </button>
          </form>
          <div className="flex flex-wrap items-center gap-2">
            <input ref={fileRef} type="file" accept=".csv,text/csv" className="hidden" onChange={(e) => void runImport(e.target.files?.[0])} />
            <button
              type="button"
              disabled={importing}
              onClick={() => fileRef.current?.click()}
              className="rounded-lg border border-slate-300 px-3 py-1.5 text-sm hover:bg-slate-50 disabled:opacity-50"
            >
              {importing ? "読み込み・登録中…" : "CSVを読み込んで登録"}
            </button>
          </div>
        </div>
        {importMsg && <p className="mb-2 text-sm text-emerald-700">{importMsg}</p>}
        {importErr && <p className="mb-2 text-sm text-rose-600">{importErr}</p>}
        <div className="overflow-x-auto">
          <table className="min-w-full text-left text-sm">
            <thead>
              <tr className="border-b border-slate-200 text-slate-500">
                <th className="py-2 pr-3">コード</th>
                <th className="py-2 pr-3">銘柄名</th>
                <th className="py-2 pr-3">業種</th>
                <th className="py-2 pr-3 text-right">保有株数（実）</th>
                <th className="py-2 pr-3">チャート</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <StockTableRow key={r.id} row={r} />
              ))}
            </tbody>
          </table>
          {rows.length === 0 && (
            <p className="py-6 text-center text-sm text-slate-500">
              {scopeAll
                ? "該当する銘柄がありません"
                : "実取引の保有銘柄がありません。CSV で登録した銘柄は「全銘柄」で表示されます。"}
            </p>
          )}
        </div>
      </section>
    </div>
  )
}

function StockTableRow({ row }: { row: StockListRow }) {
  return (
    <tr className="border-b border-slate-100">
      <td className="py-2 pr-3 font-mono">{row.code}</td>
      <td className="py-2 pr-3">
        <Link to={`/stocks/${row.id}`} className="text-indigo-600 hover:underline">
          {row.name}
        </Link>
      </td>
      <td className="py-2 pr-3 text-slate-600">{row.industry_name}</td>
      <td className="py-2 pr-3 text-right tabular-nums">{row.holding_shares_real}</td>
      <td className="py-2 pr-3">
        <a href={row.tradingview_url} target="_blank" rel="noreferrer" className="text-indigo-600 hover:underline">
          TradingView
        </a>
      </td>
    </tr>
  )
}
