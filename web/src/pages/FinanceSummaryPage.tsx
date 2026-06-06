import { useCallback, useEffect, useMemo, useState } from "react"
import { ActualEditorModal } from "../components/ActualEditorModal.tsx"
import { ImportModal } from "../components/ImportModal.tsx"
import { ForecastFormModal } from "../components/ForecastFormModal.tsx"
import { ForecastBulkEditorModal } from "../components/ForecastBulkEditorModal.tsx"
import { MonthlyBalanceFormModal } from "../components/MonthlyBalanceFormModal.tsx"
import {
  api,
  type CategoryKind,
  type DashboardExpenseLineItem,
  type DashboardSummary,
  type FiscalActualMonthRow,
  type Forecast,
} from "../lib/api.ts"
import { apiErrorMessage } from "../lib/errors.ts"
import { formatRecurringTypeLabel } from "../lib/labels.ts"
import { formatYen, formatYenDelta } from "../lib/format.ts"
import { useFetch } from "../lib/useFetch.ts"

type Mode = "実" | "予"

type MonthSummary = {
  month: string
  income: { amount: number; mode: Mode }
  expense: { amount: number; mode: Mode }
  balance: { amount: number; mode: Mode }
}

type ForecastTarget = {
  kind: CategoryKind
  month: string
  initialAmount?: number
}

export function FinanceSummaryPage() {
  const [month, setMonth] = useState(INITIAL_MONTH_INPUT)
  const [actualEditorOpen, setActualEditorOpen] = useState(false)
  const [importOpen, setImportOpen] = useState(false)
  const [forecastTarget, setForecastTarget] = useState<ForecastTarget | null>(null)
  const [bulkEditorOpen, setBulkEditorOpen] = useState(false)
  const [monthEndFormMonth, setMonthEndFormMonth] = useState(INITIAL_MONTH_INPUT)
  const [monthEndBalanceDraft, setMonthEndBalanceDraft] = useState<string | null>(null)
  const [monthEndSaving, setMonthEndSaving] = useState(false)
  const [monthEndError, setMonthEndError] = useState<string | null>(null)
  const [monthlyBalanceModalMonth, setMonthlyBalanceModalMonth] = useState<string | null>(null)
  const [recurringActualsBusy, setRecurringActualsBusy] = useState(false)
  const [recurringActualsError, setRecurringActualsError] = useState<string | null>(null)
  const [expenseBreakdownOpen, setExpenseBreakdownOpen] = useState(false)

  const forecastLoader = useCallback(() => api.forecasts(), [])
  const forecastState = useFetch<Forecast[]>(forecastLoader)
  const dashboardLoader = useCallback(() => api.dashboard(monthInputToDate(month)), [month])
  const dashboardState = useFetch(dashboardLoader)
  const monthEndDashboardLoader = useCallback(
    () => api.dashboard(monthInputToDate(monthEndFormMonth)),
    [monthEndFormMonth],
  )
  const monthEndDashboardState = useFetch(monthEndDashboardLoader)
  const fiscalActualsLoader = useCallback(
    () => api.fiscalActuals(monthInputToDate(month)),
    [month],
  )
  const fiscalActualsState = useFetch(fiscalActualsLoader)

  const openForecast = (target: ForecastTarget) => setForecastTarget(target)
  const closeForecast = () => setForecastTarget(null)
  const setMonthWithReset = (nextMonth: string) => {
    setMonth(nextMonth)
    setMonthEndBalanceDraft(null)
    setExpenseBreakdownOpen(false)
  }
  const onForecastSaved = () => {
    closeForecast()
    forecastState.refetch()
    fiscalActualsState.refetch()
  }

  const syncRecurringActualsForCurrentNext = async () => {
    setRecurringActualsBusy(true)
    setRecurringActualsError(null)
    try {
      await api.syncActuals({ expense_scope: "recurring", month: monthInputToDate(month) })
      await fiscalActualsState.refetch()
      await dashboardState.refetch()
    } catch (err) {
      setRecurringActualsError(apiErrorMessage(err))
    } finally {
      setRecurringActualsBusy(false)
    }
  }

  // 選択月の単発のみ台帳を揃える（定期は「定期実績を作成」で選択月の今年度12ヶ月）
  /* month のみで再同期。useFetch の戻りオブジェクトは毎レンダーで新参照になり得るため dashboardState / fiscalActualsState 全体は依存に入れない */
  /* eslint-disable react-hooks/exhaustive-deps */
  useEffect(() => {
    let cancelled = false
    void (async () => {
      try {
        await api.syncActuals({ month: monthInputToDate(month), expense_scope: "one_time" })
      } catch {
        // 同期失敗時も内訳は読みに行く
      }
      if (cancelled) return
      fiscalActualsState.refetch()
      dashboardState.refetch()
    })()
    return () => {
      cancelled = true
    }
  }, [month])
  /* eslint-enable react-hooks/exhaustive-deps */

  const fetchedMonthEndBalanceInput =
    monthEndDashboardState.status === "success"
      ? String(toNumber(monthEndDashboardState.data.monthly_balance))
      : ""
  const monthEndBalanceInput = monthEndBalanceDraft ?? fetchedMonthEndBalanceInput

  const selectedMonth = monthInputToDate(month)
  const fiscalMonths = useMemo(() => buildFiscalMonths(selectedMonth), [selectedMonth])
  const forecastsByKey = useMemo(() => toForecastMap(forecastState.status === "success" ? forecastState.data : []), [forecastState.data] )

  const fiscalActualsByMonth = useMemo(() => {
    const map = new Map<string, FiscalActualMonthRow>()
    if (fiscalActualsState.status !== "success") return map
    for (const row of fiscalActualsState.data) {
      const key = normalizeMonthKey(row.month)
      map.set(key, row)
    }
    return map
  }, [fiscalActualsState.data])

  const yearlySummary: MonthSummary[] = useMemo(
    () =>
      fiscalMonths.reduce<MonthSummary[]>((rows, m) => {
        const act = fiscalActualsByMonth.get(m)
        const forecastIncome = forecastsByKey.get(keyOf("income", m)) ?? 0
        const forecastExpense = forecastsByKey.get(keyOf("expense", m)) ?? 0
        const useIncomeActual = act?.has_income_actual ?? false
        const useExpenseActual = act?.has_one_time_expense_actual ?? false
        const income = useIncomeActual ? toNumber(act!.income_actual) : forecastIncome
        const expense = useExpenseActual ? toNumber(act!.expense_actual) : forecastExpense
        const incomeMode: Mode = useIncomeActual ? "実" : "予"
        const expenseMode: Mode = useExpenseActual ? "実" : "予"
        const previousBalance = rows.length > 0 ? rows[rows.length - 1].balance.amount : 0
        const rolledBalance = previousBalance + income - expense
        const storedBalance =
          act?.has_monthly_balance && act.monthly_balance_amount != null && act.monthly_balance_amount !== ""
            ? toNumber(act.monthly_balance_amount)
            : null
        const balanceAmount =
          storedBalance !== null && Number.isFinite(storedBalance) ? storedBalance : rolledBalance
        const balanceMode: Mode = act?.has_monthly_balance ? "実" : "予"
        rows.push({
          month: dateToRowMonth(m),
          income: { amount: income, mode: incomeMode },
          expense: { amount: expense, mode: expenseMode },
          balance: { amount: balanceAmount, mode: balanceMode },
        })
        return rows
      }, []),
    [fiscalMonths, forecastsByKey, fiscalActualsByMonth],
  )

  const monthIncome = forecastsByKey.get(keyOf("income", selectedMonth)) ?? 0
  const monthExpense = forecastsByKey.get(keyOf("expense", selectedMonth)) ?? 0
  const selectedIdx = fiscalMonths.findIndex((m) => m === selectedMonth)
  const selectedMonthRow = selectedIdx >= 0 ? yearlySummary[selectedIdx] : null
  const summaryIncomeAmount = selectedMonthRow?.income.amount ?? monthIncome
  const summaryExpenseAmount = selectedMonthRow?.expense.amount ?? monthExpense
  const summaryIncomeMode = selectedMonthRow?.income.mode ?? "予"
  const summaryExpenseMode = selectedMonthRow?.expense.mode ?? "予"
  const expectedBalance =
    selectedIdx >= 0 ? yearlySummary[selectedIdx].balance.amount : monthIncome - monthExpense
  const previousBalance = selectedIdx > 0 ? yearlySummary[selectedIdx - 1].balance.amount : 0
  const lastMonthDiff = expectedBalance - previousBalance

  const saveMonthEndBalance = async () => {
    const amount = Number(monthEndBalanceInput)
    if (!Number.isFinite(amount) || amount < 0) {
      setMonthEndError("月末残高は0以上の数字で入力してください")
      return
    }
    setMonthEndSaving(true)
    setMonthEndError(null)
    try {
      await api.upsertMonthlyBalance({ month: monthInputToDate(monthEndFormMonth), amount: Math.round(amount) })
      setMonthEndBalanceDraft(null)
      dashboardState.refetch()
      monthEndDashboardState.refetch()
      fiscalActualsState.refetch()
    } catch (error) {
      setMonthEndError(apiErrorMessage(error))
    } finally {
      setMonthEndSaving(false)
    }
  }

  return (
    <div className="space-y-4">
      <section className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm sm:p-5">
        <div className="flex flex-col gap-3 border-b border-slate-100 pb-4 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex flex-wrap items-center gap-2 sm:gap-3">
            <button
              type="button"
              className="rounded-lg border border-slate-300 px-2 py-1 text-sm"
              onClick={() => setMonthWithReset(addMonthsToMonthInput(month, -1))}
            >
              {"<"}
            </button>
            <h2 className="text-lg font-bold sm:text-xl">{month.replace("-", "年")}月</h2>
            <button
              type="button"
              className="rounded-lg border border-slate-300 px-2 py-1 text-sm"
              onClick={() => setMonthWithReset(addMonthsToMonthInput(month, 1))}
            >
              {">"}
            </button>
            <button
              type="button"
              className="rounded-lg border border-slate-300 px-3 py-1 text-sm"
              onClick={() => {
                setMonthWithReset(INITIAL_MONTH_INPUT)
              }}
            >
              今月へ
            </button>
            <input
              type="month"
              value={month}
              onChange={(event) => setMonthWithReset(event.target.value)}
              className="rounded-lg border border-slate-300 px-3 py-1 text-sm"
            />
          </div>
          <div className="flex w-full flex-wrap items-center gap-2 text-sm sm:w-auto">
            <button
              type="button"
              onClick={() => setActualEditorOpen(true)}
              className="w-full rounded-lg bg-indigo-600 px-3 py-1.5 font-medium text-white hover:bg-indigo-500 sm:w-auto"
            >
              ＋ 単発の支出を追加
            </button>
            <button
              type="button"
              onClick={() => setImportOpen(true)}
              className="w-full rounded-lg border border-indigo-300 bg-white px-3 py-1.5 font-medium text-indigo-700 hover:bg-indigo-50 sm:w-auto"
            >
              取込
            </button>
          </div>
        </div>

        <div className="mt-4 grid gap-3 sm:grid-cols-3">
          <article className="rounded-xl border border-slate-200 bg-indigo-50 p-4">
            <p className="text-xs font-medium text-indigo-700">月末予想残高（予）</p>
            <p className="mt-1 text-xl font-bold text-indigo-700 sm:text-2xl">{formatYen(expectedBalance)}</p>
            <p className="mt-1 text-xs text-indigo-700">前月比 {formatYenDelta(lastMonthDiff)}</p>
          </article>
          <SummaryCard
            label="収入"
            amount={summaryIncomeAmount}
            mode={summaryIncomeMode}
            tone="emerald"
            onEditForecast={
              summaryIncomeMode === "予"
                ? () => openForecast({ kind: "income", month: selectedMonth, initialAmount: monthIncome })
                : undefined
            }
          />
          <SummaryCard
            label="支出"
            amount={summaryExpenseAmount}
            mode={summaryExpenseMode}
            tone="rose"
            onEditForecast={
              summaryExpenseMode === "予"
                ? () => openForecast({ kind: "expense", month: selectedMonth, initialAmount: monthExpense })
                : undefined
            }
            onActualBadgeClick={summaryExpenseMode === "実" ? () => setExpenseBreakdownOpen(true) : undefined}
          />
        </div>
      </section>

      <section className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm sm:p-5">
        <div className="mb-3 flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <h2 className="text-lg font-semibold leading-tight">
            今年度サマリ（{dateToRowMonth(fiscalMonths[0])}〜{dateToRowMonth(fiscalMonths[fiscalMonths.length - 1])}）
          </h2>
          <div className="flex w-full flex-wrap items-center gap-2 sm:w-auto sm:justify-end">
            <button
              type="button"
              onClick={() => void syncRecurringActualsForCurrentNext()}
              disabled={recurringActualsBusy}
              className="w-full rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-sm hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-50 sm:w-auto"
            >
              {recurringActualsBusy ? "作成中…" : "定期実績を作成"}
            </button>
            <button
              type="button"
              onClick={() => setBulkEditorOpen(true)}
              className="w-full rounded-lg border border-slate-300 px-3 py-1.5 text-sm sm:w-auto"
            >
              予測をまとめて編集
            </button>
          </div>
        </div>
        {recurringActualsError && (
          <p className="mb-3 rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-xs text-rose-700">{recurringActualsError}</p>
        )}
        {forecastState.status === "error" && (
          <p className="mb-3 rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700">
            予測の読み込みに失敗しました: {apiErrorMessage(forecastState.error)}
          </p>
        )}
        <div className="overflow-x-auto rounded-lg border border-slate-200">
          <table className="min-w-[640px] divide-y divide-slate-200 text-xs sm:min-w-full sm:text-sm">
            <thead className="bg-slate-50 text-left text-xs text-slate-500">
              <tr>
                <th className="px-2 py-2 sm:px-3">月</th>
                <th className="px-2 py-2 sm:px-3">収入</th>
                <th className="px-2 py-2 sm:px-3">支出</th>
                <th className="px-2 py-2 sm:px-3">月末残高</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {yearlySummary.map((row) => (
                <tr key={row.month}>
                  <td className="px-2 py-2 font-medium whitespace-nowrap sm:px-3">{row.month}</td>
                  <td className="px-2 py-2 whitespace-nowrap sm:px-3">
                    <ValueWithMode
                      amount={row.income.amount}
                      mode={row.income.mode}
                      onEditForecast={
                        row.income.mode === "予"
                          ? () =>
                              openForecast({
                                kind: "income",
                                month: rowMonthToDate(row.month),
                                initialAmount: forecastsByKey.get(keyOf("income", rowMonthToDate(row.month))) ?? 0,
                              })
                          : undefined
                      }
                    />
                  </td>
                  <td className="px-2 py-2 whitespace-nowrap sm:px-3">
                    <ValueWithMode
                      amount={row.expense.amount}
                      mode={row.expense.mode}
                      onEditForecast={
                        row.expense.mode === "予"
                          ? () =>
                              openForecast({
                                kind: "expense",
                                month: rowMonthToDate(row.month),
                                initialAmount: forecastsByKey.get(keyOf("expense", rowMonthToDate(row.month))) ?? 0,
                              })
                          : undefined
                      }
                      onActualBreakdown={
                        row.expense.mode === "実"
                          ? () => {
                              const nextMonthInput = rowMonthToDate(row.month).slice(0, 7)
                              setMonth(nextMonthInput)
                              setMonthEndBalanceDraft(null)
                              setExpenseBreakdownOpen(true)
                            }
                          : undefined
                      }
                      actualBreakdownAriaLabel={`${row.month}の支出内訳をモーダルで開く`}
                    />
                  </td>
                  <td className="px-2 py-2 whitespace-nowrap sm:px-3">
                    <ValueWithMode
                      amount={row.balance.amount}
                      mode={row.balance.mode}
                      onMonthlyBalanceEdit={() => {
                        const iso = rowMonthToDate(row.month)
                        setMonthEndFormMonth(iso.slice(0, 7))
                        setMonthEndBalanceDraft(null)
                        setMonthlyBalanceModalMonth(iso)
                      }}
                      monthlyBalanceAriaLabel={`${row.month}の月末残高を編集`}
                    />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm sm:p-5">
        <h2 className="mb-2 text-lg font-semibold">月末残高の作成</h2>
        <p className="mb-3 text-xs text-slate-500">
          対象月を選んで保存します。今年度サマリの月末残高バッジから開いても同じです。
        </p>
        <div className="flex flex-col items-stretch gap-3 sm:flex-row sm:flex-wrap sm:items-center">
          <label className="flex w-full flex-wrap items-center gap-2 text-sm sm:w-auto">
            <span className="text-slate-600">対象月</span>
            <input
              type="month"
              value={monthEndFormMonth}
              onChange={(event) => {
                setMonthEndFormMonth(event.target.value)
                setMonthEndBalanceDraft(null)
              }}
              className="w-full rounded-lg border border-slate-300 px-3 py-1.5 text-sm sm:w-auto"
            />
          </label>
            <input
            type="number"
            min="0"
            placeholder={monthEndDashboardState.status === "loading" ? "読み込み中…" : "例: 2300000"}
            value={monthEndBalanceInput}
            onChange={(event) => setMonthEndBalanceDraft(event.target.value)}
            disabled={monthEndDashboardState.status !== "success"}
              className="w-full min-w-0 rounded-lg border border-slate-300 px-3 py-2 text-sm disabled:bg-slate-50 sm:w-48"
          />
          <button
            type="button"
            onClick={() => void saveMonthEndBalance()}
            disabled={monthEndSaving || monthEndDashboardState.status !== "success"}
            className="w-full rounded-lg bg-indigo-600 px-3 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:cursor-not-allowed disabled:bg-indigo-300 sm:w-auto"
          >
            {monthEndSaving ? "保存中…" : "保存"}
          </button>
        </div>
        {monthEndError && <p className="mt-2 text-sm text-rose-700">{monthEndError}</p>}
      </section>

      {actualEditorOpen && (
        <ActualEditorModal
          key={month}
          month={month}
          onClose={() => setActualEditorOpen(false)}
          onSaved={() => {
            setActualEditorOpen(false)
            dashboardState.refetch()
            fiscalActualsState.refetch()
          }}
        />
      )}
      {importOpen && (
        <ImportModal
          onClose={() => setImportOpen(false)}
          onImported={() => {
            setImportOpen(false)
            dashboardState.refetch()
            fiscalActualsState.refetch()
            forecastState.refetch()
          }}
        />
      )}
      {forecastTarget && (
        <ForecastFormModal
          kind={forecastTarget.kind}
          month={forecastTarget.month}
          initialAmount={forecastTarget.initialAmount}
          onClose={closeForecast}
          onSaved={onForecastSaved}
        />
      )}
      {monthlyBalanceModalMonth && (
        <MonthlyBalanceFormModal
          key={monthlyBalanceModalMonth}
          month={monthlyBalanceModalMonth}
          onClose={() => setMonthlyBalanceModalMonth(null)}
          onSaved={() => {
            setMonthlyBalanceModalMonth(null)
            setMonthEndBalanceDraft(null)
            fiscalActualsState.refetch()
            monthEndDashboardState.refetch()
            dashboardState.refetch()
          }}
        />
      )}
      {bulkEditorOpen && (
        <ForecastBulkEditorModal
          startMonth={monthInputToDate(INITIAL_MONTH_INPUT)}
          forecasts={forecastState.status === "success" ? forecastState.data : []}
          onClose={() => setBulkEditorOpen(false)}
          onSaved={() => {
            setBulkEditorOpen(false)
            forecastState.refetch()
          }}
        />
      )}
      {expenseBreakdownOpen && (
        <div
          className="fixed inset-0 z-30 flex items-center justify-center bg-slate-900/40 p-4"
          onClick={(e) => {
            if (e.target === e.currentTarget) setExpenseBreakdownOpen(false)
          }}
        >
          <div
            className="max-h-[90vh] w-full max-w-4xl overflow-y-auto rounded-2xl bg-white p-4 shadow-xl sm:p-5"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="mb-4 flex items-center justify-between gap-2">
              <h3 className="text-lg font-semibold text-slate-900">
                支出の内訳（{dateToRowMonth(selectedMonth)}）
              </h3>
              <button
                type="button"
                className="-m-1 flex h-11 min-w-11 shrink-0 items-center justify-center rounded-lg text-2xl leading-none text-slate-500 hover:bg-slate-100 hover:text-slate-800"
                onClick={() => setExpenseBreakdownOpen(false)}
                aria-label="閉じる"
              >
                ×
              </button>
            </div>
            <ExpenseBreakdownCard key={month} state={dashboardState} expenseMode={summaryExpenseMode} />
          </div>
        </div>
      )}
    </div>
  )
}

const INITIAL_MONTH_INPUT = toMonthInput(Date.now())

const TONE: Record<"emerald" | "rose", { bg: string; text: string }> = {
  emerald: { bg: "bg-emerald-50", text: "text-emerald-700" },
  rose: { bg: "bg-rose-50", text: "text-rose-700" },
}

function SummaryCard({
  label,
  amount,
  mode,
  tone,
  onEditForecast,
  onActualBadgeClick,
}: {
  label: string
  amount: number
  mode: Mode
  tone: "emerald" | "rose"
  onEditForecast?: () => void
  /** 支出が「実」のとき、内訳モーダルを開く（予のときは onEditForecast で予測編集） */
  onActualBadgeClick?: () => void
}) {
  const t = TONE[tone]
  const badgeClick = mode === "予" ? onEditForecast : onActualBadgeClick
  const openBreakdownByWholeCard = mode === "実" && onActualBadgeClick

  if (openBreakdownByWholeCard) {
    return (
      <article className={`rounded-xl border border-slate-200 ${t.bg} p-4`}>
        <button
          type="button"
          className="w-full text-left focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-400 focus-visible:ring-offset-2"
          onClick={onActualBadgeClick}
          aria-label={`${label}の内訳をモーダルで開く`}
        >
          <div className="flex items-center justify-between">
            <p className={`text-xs font-medium ${t.text}`}>{label}</p>
            <span className="rounded-full bg-slate-200 px-2 py-0.5 text-xs text-slate-700">実</span>
          </div>
          <p className={`mt-1 text-lg font-semibold ${t.text}`}>{formatYen(amount)}</p>
        </button>
      </article>
    )
  }

  return (
    <article className={`rounded-xl border border-slate-200 ${t.bg} p-4`}>
      <div className="flex items-center justify-between">
        <p className={`text-xs font-medium ${t.text}`}>{label}</p>
        <ModeBadge
          mode={mode}
          onClick={badgeClick}
          ariaLabel={
            mode === "予" && onEditForecast
              ? `${label}の予測を編集`
              : mode === "実" && onActualBadgeClick
                ? `${label}の内訳をモーダルで開く`
                : undefined
          }
        />
      </div>
      <p className={`mt-1 text-lg font-semibold ${t.text}`}>{formatYen(amount)}</p>
    </article>
  )
}

function ValueWithMode({
  amount,
  mode,
  onEditForecast,
  onMonthlyBalanceEdit,
  onActualBreakdown,
  actualBreakdownAriaLabel,
  monthlyBalanceAriaLabel,
}: {
  amount: number
  mode: Mode
  onEditForecast?: () => void
  onMonthlyBalanceEdit?: () => void
  /** 今年度サマリの「支出・実」など：内訳モーダルを開く */
  onActualBreakdown?: () => void
  actualBreakdownAriaLabel?: string
  /** 今年度サマリの月末残高セル：ボタン化するときの説明 */
  monthlyBalanceAriaLabel?: string
}) {
  const badgeClick =
    onMonthlyBalanceEdit ?? (mode === "実" && onActualBreakdown ? onActualBreakdown : onEditForecast)
  const badgeAria =
    onMonthlyBalanceEdit != null
      ? undefined
      : mode === "実" && onActualBreakdown
        ? actualBreakdownAriaLabel ?? "支出の内訳をモーダルで開く"
        : undefined

  /** 今年度サマリの月末残高：金額＋予／実をまとめて押せる */
  if (onMonthlyBalanceEdit) {
    const pillClass =
      mode === "実"
        ? "rounded-full bg-slate-200 px-2 py-0.5 text-xs text-slate-700"
        : "rounded-full bg-indigo-100 px-2 py-0.5 text-xs text-indigo-700"
    return (
      <button
        type="button"
        className="inline-flex items-center gap-2 rounded-md border border-transparent px-1 py-0.5 text-left text-inherit hover:bg-slate-100/80 focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-400"
        onClick={onMonthlyBalanceEdit}
        aria-label={monthlyBalanceAriaLabel ?? "月末残高を編集"}
      >
        <span>{formatYen(amount)}</span>
        <span className={pillClass}>{mode}</span>
      </button>
    )
  }

  /** 今年度サマリの支出「実」：金額だけでは気づきにくいので、金額＋バッジをまとめて押せる */
  if (mode === "実" && onActualBreakdown) {
    return (
      <button
        type="button"
        className="inline-flex items-center gap-2 rounded-md border border-transparent px-1 py-0.5 text-left text-inherit hover:bg-slate-100/80 focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-400"
        onClick={onActualBreakdown}
        aria-label={actualBreakdownAriaLabel ?? "支出の内訳をモーダルで開く"}
      >
        <span>{formatYen(amount)}</span>
        <span className="rounded-full bg-slate-200 px-2 py-0.5 text-xs text-slate-700">実</span>
      </button>
    )
  }

  return (
    <span className="inline-flex items-center gap-2">
      <span>{formatYen(amount)}</span>
      <ModeBadge mode={mode} onClick={badgeClick} ariaLabel={badgeAria} />
    </span>
  )
}

function ModeBadge({
  mode,
  onClick,
  ariaLabel,
}: {
  mode: Mode
  onClick?: () => void
  ariaLabel?: string
}) {
  const hover =
    onClick && mode === "実" ? "cursor-pointer hover:bg-slate-300" : onClick ? "cursor-pointer hover:bg-indigo-200" : ""
  const className = `rounded-full px-2 py-0.5 text-xs ${
    mode === "実" ? "bg-slate-200 text-slate-700" : "bg-indigo-100 text-indigo-700"
  } ${hover}`

  if (onClick) {
    return (
      <button type="button" onClick={onClick} className={className} aria-label={ariaLabel ?? `${mode}を編集`}>
        {mode}
      </button>
    )
  }
  return <span className={className}>{mode}</span>
}

type BreakdownItem = { label: string; amount: number; mode: Mode }

function ExpenseBreakdownCard({
  state,
  expenseMode,
}: {
  state: {
    status: "loading" | "success" | "error"
    data: DashboardSummary | null
    error: Error | null
  }
  /** 実績が無く上部が予測のみのときの案内文に使用（単発が無くサマリーが「予」の月でも定期の明細行はある） */
  expenseMode: Mode
}) {
  const [breakdownView, setBreakdownView] = useState<"payment" | "category" | "lines">("payment")
  const dashboard = state.status === "success" ? state.data : null
  const paymentItems = dashboard
    ? dashboard.expense_by_payment.map((item) => ({ label: item.label, amount: toNumber(item.amount), mode: item.mode as Mode }))
    : []
  const categoryGroups: LocalCategoryBreakdownGroup[] = dashboard
    ? dashboard.expense_by_category_groups.map((group) => ({
        major: group.major,
        mode: group.mode as Mode,
        minors: group.minors.map((minor) => ({
          label: minor.label,
          amount: toNumber(minor.amount),
          mode: minor.mode as Mode,
        })),
      }))
    : []
  const lineItems: DashboardExpenseLineItem[] = dashboard?.expense_line_items ?? []
  const hasBreakdownRows = paymentItems.length > 0 || categoryGroups.length > 0 || lineItems.length > 0

  return (
    <div className="rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
      <div className="mb-3 flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        <h2 className="text-base font-semibold text-slate-800">表示月の支出</h2>
        <div className="inline-flex flex-wrap rounded-full bg-slate-100 p-0.5 text-xs">
          <BreakdownTab active={breakdownView === "payment"} onClick={() => setBreakdownView("payment")}>
            支払方法別
          </BreakdownTab>
          <BreakdownTab active={breakdownView === "category"} onClick={() => setBreakdownView("category")}>
            カテゴリ別
          </BreakdownTab>
          <BreakdownTab active={breakdownView === "lines"} onClick={() => setBreakdownView("lines")}>
            一覧（単発含む）
          </BreakdownTab>
        </div>
      </div>
      {state.status === "loading" && <p className="text-sm text-slate-500">読み込み中…</p>}
      {state.status === "error" && (
        <p className="text-sm text-rose-700">内訳の読み込みに失敗しました: {apiErrorMessage(state.error)}</p>
      )}
      {state.status === "success" &&
        (breakdownView === "payment" ? (
          <BreakdownList items={paymentItems} accent="text-rose-600" />
        ) : breakdownView === "category" ? (
          <CategoryBreakdownList groups={categoryGroups} />
        ) : lineItems.length === 0 ? (
          <p className="text-sm text-slate-500">この月は実績ベースの支出明細がありません。</p>
        ) : (
          <ExpenseLineItemsList items={lineItems} />
        ))}
      {state.status === "success" && dashboard && !hasBreakdownRows && (
        <p className="mt-2 text-xs text-slate-500">
          {expenseMode === "予"
            ? "この月は実績ベースの支出内訳がまだありません。上部の支出合計は予測です。"
            : "実績取引はある設定ですが、内訳を表示できませんでした。"}
        </p>
      )}
    </div>
  )
}

function ExpenseLineItemsList({ items }: { items: DashboardExpenseLineItem[] }) {
  if (items.length === 0) {
    return <p className="text-sm text-slate-500">この月に紐づく支出実績行がありません</p>
  }

  return (
    <ul className="divide-y divide-slate-100">
      {items.map((row) => {
        const memo = row.memo?.trim()
        const title = memo ? `${row.minor}（${memo}）` : row.minor
        const sub = `${row.major} · ${row.payment}`
        const kind = formatRecurringTypeLabel(row.expense_type)
        return (
          <li key={row.expense_id} className="py-3 text-sm">
            <div className="flex flex-col gap-1 sm:flex-row sm:items-start sm:justify-between">
              <div className="min-w-0">
                <div className="font-medium text-slate-800">{title}</div>
                <div className="text-xs text-slate-500">{sub}</div>
                <div className="mt-1">
                  <span className="rounded bg-slate-100 px-1.5 py-0.5 text-xs text-slate-600">{kind}</span>
                </div>
              </div>
              <div className="flex shrink-0 items-center sm:pt-0.5">
                <span className="font-semibold text-rose-600">{formatYen(toNumber(row.amount))}</span>
              </div>
            </div>
          </li>
        )
      })}
    </ul>
  )
}

type LocalCategoryBreakdownGroup = {
  major: string
  mode: Mode
  minors: BreakdownItem[]
}

function CategoryBreakdownList({ groups }: { groups: LocalCategoryBreakdownGroup[] }) {
  if (groups.length === 0) {
    return <p className="text-sm text-slate-500">データがありません</p>
  }

  return (
    <ul className="space-y-2">
      {groups.map((group) => {
        const total = group.minors.reduce((sum, minor) => sum + minor.amount, 0)
        return (
          <li key={group.major} className="rounded-lg border border-slate-200">
            <details open className="group">
              <summary className="flex cursor-pointer list-none items-center justify-between px-3 py-2 text-sm">
                <span className="font-medium">{group.major}</span>
                <span className="font-semibold text-rose-600">{formatYen(total)}</span>
              </summary>
              <ul className="border-t border-slate-100">
                {group.minors.map((minor) => (
                  <li key={`${group.major}-${minor.label}`} className="flex items-center justify-between px-3 py-2 text-sm">
                    <span className="text-slate-700">{minor.label}</span>
                    <span className="font-semibold text-rose-600">{formatYen(minor.amount)}</span>
                  </li>
                ))}
              </ul>
            </details>
          </li>
        )
      })}
    </ul>
  )
}

function BreakdownList({ items, accent }: { items: BreakdownItem[]; accent: string }) {
  if (items.length === 0) {
    return <p className="text-sm text-slate-500">データがありません</p>
  }
  return (
    <ul className="divide-y divide-slate-100">
      {items.map((item) => (
        <li key={item.label} className="flex items-center justify-between py-2 text-sm">
          <span>{item.label}</span>
          <span className={`font-semibold ${accent}`}>{formatYen(item.amount)}</span>
        </li>
      ))}
    </ul>
  )
}

function BreakdownTab({
  active,
  onClick,
  children,
}: {
  active: boolean
  onClick: () => void
  children: React.ReactNode
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`rounded-full px-3 py-1 transition-colors ${
        active ? "bg-white text-slate-800 shadow-sm" : "text-slate-500 hover:text-slate-700"
      }`}
    >
      {children}
    </button>
  )
}

function monthInputToDate(value: string): string {
  return `${value}-01`
}

function rowMonthToDate(rowMonth: string): string {
  // "2026/05" → "2026-05-01"
  return `${rowMonth.replace("/", "-")}-01`
}

function toMonthInput(value: number): string {
  const d = new Date(value)
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, "0")
  return `${y}-${m}`
}

function addMonthsToMonthInput(monthInput: string, deltaMonths: number): string {
  const [yRaw, mRaw] = monthInput.split("-")
  const y = Number(yRaw)
  const m0 = Number(mRaw) - 1 // 0-based
  const d = new Date(y, m0, 1)
  d.setMonth(d.getMonth() + deltaMonths)
  const yy = d.getFullYear()
  const mm = String(d.getMonth() + 1).padStart(2, "0")
  return `${yy}-${mm}`
}

function buildFiscalMonths(selectedMonth: string): string[] {
  const [y, m] = selectedMonth.split("-").map(Number)
  const fiscalYear = m >= 4 ? y : y - 1
  const months: string[] = []
  for (let i = 0; i < 12; i += 1) {
    const date = new Date(fiscalYear, 3 + i, 1)
    const yy = date.getFullYear()
    const mm = String(date.getMonth() + 1).padStart(2, "0")
    months.push(`${yy}-${mm}-01`)
  }
  return months
}

function keyOf(kind: CategoryKind, month: string): string {
  return `${kind}:${month}`
}

function toForecastMap(forecasts: Forecast[]): Map<string, number> {
  const map = new Map<string, number>()
  forecasts.forEach((f) => {
    const amount = toNumber(f.amount)
    map.set(keyOf(f.kind, normalizeMonthKey(String(f.month))), Number.isFinite(amount) ? amount : 0)
  })
  return map
}

function toNumber(value: string | number): number {
  const n = typeof value === "string" ? Number(value) : value
  return Number.isFinite(n) ? n : 0
}

function dateToRowMonth(date: string): string {
  const [y, m] = date.split("-")
  return `${y}/${m}`
}

/** API の month と fiscalMonths のキーを揃える。ISO日時は先頭10文字だけ取るとUTC暦で月がずれるため Date 経由にする */
function normalizeMonthKey(month: string): string {
  const s = String(month).trim()
  if (s === "") return s

  if (s.length > 10 || /[tT]/.test(s)) {
    const d = new Date(s)
    if (!Number.isNaN(d.getTime())) {
      return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-01`
    }
  }

  const dateOnly = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s)
  if (dateOnly) {
    const [, y, mo] = dateOnly
    return `${y}-${mo}-01`
  }

  const d = new Date(s)
  if (!Number.isNaN(d.getTime())) {
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-01`
  }

  const head = s.slice(0, 10)
  const [y, mo] = head.split("-")
  if (!y || !mo) return s
  return `${y}-${mo.padStart(2, "0")}-01`
}
