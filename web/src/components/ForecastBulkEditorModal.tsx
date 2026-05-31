import { useMemo, useState } from "react"
import { api, type Forecast } from "../lib/api.ts"
import { apiErrorMessage } from "../lib/errors.ts"
import { FormActions, FormError, Modal } from "./Modal.tsx"

type ForecastKind = "income" | "expense"

type Row = {
  month: string
  income: string
  expense: string
}

type Props = {
  onClose: () => void
  onSaved: () => void
  forecasts: Forecast[]
  startMonth: string
}

export function ForecastBulkEditorModal({ onClose, onSaved, forecasts, startMonth }: Props) {
  const initialRows = useMemo(() => buildRows(forecasts, startMonth), [forecasts, startMonth])
  const [rows, setRows] = useState<Row[]>(initialRows)
  const [submitting, setSubmitting] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [bulkKind, setBulkKind] = useState<ForecastKind>("expense")
  const [bulkFromMonth, setBulkFromMonth] = useState("")
  const [bulkAmount, setBulkAmount] = useState("")

  const bulkTargetCount = useMemo(
    () => countRowsFromMonth(rows, bulkFromMonth),
    [rows, bulkFromMonth],
  )

  const updateAmount = (idx: number, kind: ForecastKind, value: string) => {
    setRows((prev) =>
      prev.map((r, i) => (i === idx ? { ...r, [kind]: value } : r)),
    )
  }

  const applyBulkToRows = () => {
    if (!bulkFromMonth) {
      setErrorMessage("一括変更の開始月を選んでください")
      return
    }
    const amount = Math.round(Number(bulkAmount))
    if (!Number.isFinite(amount) || amount < 0) {
      setErrorMessage("金額は0以上の数値で入力してください")
      return
    }
    if (bulkTargetCount === 0) {
      setErrorMessage("指定月以降に更新対象の月がありません（表示中の12ヶ月の範囲内で選んでください）")
      return
    }
    const monthLabel = bulkFromMonth.replace("-", "/")
    const kindLabel = bulkKind === "income" ? "収入" : "支出"
    if (
      !window.confirm(
        `${monthLabel} 以降の ${kindLabel} 予測 ${bulkTargetCount} ヶ月分を ¥${amount.toLocaleString("ja-JP")} に揃えます（下の表に反映。保存するまでDBには書き込みません）。よろしいですか？`,
      )
    ) {
      return
    }
    const from = monthInputToRowMonth(bulkFromMonth)
    const amountStr = String(amount)
    setRows((prev) =>
      prev.map((row) => (row.month >= from ? { ...row, [bulkKind]: amountStr } : row)),
    )
    setErrorMessage(null)
  }

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setSubmitting(true)
    setErrorMessage(null)
    try {
      for (const row of rows) {
        const income = Number(row.income)
        const expense = Number(row.expense)
        if (!Number.isFinite(income) || income < 0 || !Number.isFinite(expense) || expense < 0) {
          throw new Error("金額は0以上で入力してください")
        }
        await api.upsertForecast({ kind: "income", month: row.month, amount: Math.round(income) })
        await api.upsertForecast({ kind: "expense", month: row.month, amount: Math.round(expense) })
      }
      onSaved()
    } catch (err) {
      setErrorMessage(apiErrorMessage(err))
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <Modal title="予測をまとめて編集（今月以降12ヶ月）" onClose={onClose}>
      <form className="space-y-3" onSubmit={onSubmit}>
        <FormError message={errorMessage} />
        <div className="rounded-lg border border-indigo-200 bg-indigo-50/60 px-3 py-3">
          <p className="text-sm font-medium text-slate-800">指定月以降を一括変更</p>
          <p className="mt-1 text-xs text-slate-600">
            収入または支出を選び、開始月以降の予測を同じ金額に揃えます。反映後に下部の表を確認し「保存」してください。
          </p>
          <div className="mt-3 flex flex-wrap items-end gap-3">
            <fieldset className="text-xs text-slate-600">
              <legend className="mb-1 block font-medium">種別</legend>
              <div className="flex gap-3">
                <label className="inline-flex items-center gap-1.5">
                  <input
                    type="radio"
                    name="bulkKind"
                    value="income"
                    checked={bulkKind === "income"}
                    onChange={() => setBulkKind("income")}
                    disabled={submitting}
                  />
                  収入
                </label>
                <label className="inline-flex items-center gap-1.5">
                  <input
                    type="radio"
                    name="bulkKind"
                    value="expense"
                    checked={bulkKind === "expense"}
                    onChange={() => setBulkKind("expense")}
                    disabled={submitting}
                  />
                  支出
                </label>
              </div>
            </fieldset>
            <label className="text-xs text-slate-600">
              <span className="mb-1 block font-medium">この月以降</span>
              <input
                type="month"
                value={bulkFromMonth}
                onChange={(e) => setBulkFromMonth(e.target.value)}
                disabled={submitting}
                className="rounded-md border border-slate-300 px-2 py-1 text-sm"
              />
            </label>
            <label className="text-xs text-slate-600">
              <span className="mb-1 block font-medium">金額（円）</span>
              <input
                type="number"
                min={0}
                step={1}
                value={bulkAmount}
                onChange={(e) => setBulkAmount(e.target.value)}
                disabled={submitting}
                className="w-32 rounded-md border border-slate-300 px-2 py-1 text-sm"
              />
            </label>
            <button
              type="button"
              disabled={submitting || bulkTargetCount === 0 || !bulkFromMonth}
              onClick={applyBulkToRows}
              className="rounded-lg bg-indigo-600 px-3 py-1.5 text-sm font-medium text-white hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
            >
              表に反映
            </button>
          </div>
          {bulkFromMonth && (
            <p className="mt-2 text-xs text-slate-600">
              対象: {bulkTargetCount} ヶ月
              {bulkTargetCount === 0 && "（表示中の12ヶ月の範囲外、または該当なし）"}
            </p>
          )}
        </div>
        <div className="max-h-[60vh] overflow-y-auto rounded-lg border border-slate-200">
          <table className="min-w-full divide-y divide-slate-200 text-sm">
            <thead className="bg-slate-50 text-left text-xs text-slate-500">
              <tr>
                <th className="px-3 py-2">月</th>
                <th className="px-3 py-2">収入</th>
                <th className="px-3 py-2">支出</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {rows.map((row, idx) => (
                <tr key={row.month}>
                  <td className="px-3 py-2">{formatMonth(row.month)}</td>
                  <td className="px-3 py-2">
                    <input
                      type="number"
                      min="0"
                      step="1"
                      value={row.income}
                      onChange={(e) => updateAmount(idx, "income", e.target.value)}
                      className="w-full rounded border border-slate-300 px-2 py-1"
                    />
                  </td>
                  <td className="px-3 py-2">
                    <input
                      type="number"
                      min="0"
                      step="1"
                      value={row.expense}
                      onChange={(e) => updateAmount(idx, "expense", e.target.value)}
                      className="w-full rounded border border-slate-300 px-2 py-1"
                    />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <FormActions onCancel={onClose} submitting={submitting} />
      </form>
    </Modal>
  )
}

function countRowsFromMonth(rows: Row[], fromMonthInput: string): number {
  if (!fromMonthInput) return 0
  const from = monthInputToRowMonth(fromMonthInput)
  return rows.filter((row) => row.month >= from).length
}

function monthInputToRowMonth(yyyyMm: string): string {
  return `${yyyyMm}-01`
}

function buildRows(forecasts: Forecast[], startMonth: string): Row[] {
  const map = new Map<string, number>()
  forecasts.forEach((f) => {
    const amount = typeof f.amount === "string" ? Number(f.amount) : f.amount
    map.set(`${f.kind}:${f.month}`, Number.isFinite(amount) ? amount : 0)
  })

  const rows: Row[] = []
  for (let i = 0; i < 12; i += 1) {
    const month = addMonths(startMonth, i)
    rows.push({
      month,
      income: String(map.get(`income:${month}`) ?? 0),
      expense: String(map.get(`expense:${month}`) ?? 0),
    })
  }
  return rows
}

function addMonths(date: string, delta: number): string {
  const [yRaw, mRaw] = date.split("-")
  const base = new Date(Number(yRaw), Number(mRaw) - 1, 1)
  base.setMonth(base.getMonth() + delta)
  const y = base.getFullYear()
  const m = String(base.getMonth() + 1).padStart(2, "0")
  return `${y}-${m}-01`
}

function formatMonth(date: string): string {
  const [y, m] = date.split("-")
  return `${y}/${m}`
}
