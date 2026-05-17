import { useCallback } from "react"
import { api } from "../lib/api.ts"
import { useFetch } from "../lib/useFetch.ts"

type Props = {
  value: string
  onChange: (stockId: string) => void
  required?: boolean
  disabled?: boolean
}

/** 銘柄マスタから選択（コード・銘柄名表示） */
export function StockPicker({ value, onChange, required, disabled }: Props) {
  const loader = useCallback(() => api.stocks({ scope: "all" }), [])
  const result = useFetch(loader)

  if (result.status === "loading") {
    return (
      <select disabled className="rounded-lg border border-slate-300 px-2 py-1.5 text-sm text-slate-400">
        <option>銘柄を読み込み中…</option>
      </select>
    )
  }
  if (result.status === "error") {
    return <p className="text-sm text-rose-600">{result.error.message}</p>
  }

  const stocks = result.data

  return (
    <select
      value={value}
      required={required}
      disabled={disabled}
      onChange={(e) => onChange(e.target.value)}
      className="w-full rounded-lg border border-slate-300 px-2 py-1.5 text-sm"
    >
      <option value="">銘柄を選択</option>
      {stocks.map((s) => (
        <option key={s.id} value={String(s.id)}>
          {s.code} {s.name}
        </option>
      ))}
    </select>
  )
}
