import { useCallback, useState } from "react"
import {
  api,
  type CategoryKind,
  type ExpenseMaster,
  type IncomeMaster,
  type MajorCategory,
  type MasterActual,
  type MinorCategory,
  type PaymentMethod,
} from "../lib/api.ts"
import { useFetch } from "../lib/useFetch.ts"
import { apiErrorMessage } from "../lib/errors.ts"
import { sortMajorCategories, sortMinorCategories } from "../lib/categorySort.ts"
import {
  formatPaymentMethodSchedule,
  formatPaymentMethodTypeLabel,
  formatRecurringCycleLabel,
  formatRecurringTypeLabel,
} from "../lib/labels.ts"
import { MajorCategoryFormModal } from "../components/MajorCategoryFormModal.tsx"
import { MinorCategoryFormModal } from "../components/MinorCategoryFormModal.tsx"
import { PaymentMethodFormModal } from "../components/PaymentMethodFormModal.tsx"
import { ExpenseMasterFormModal } from "../components/ExpenseMasterFormModal.tsx"
import { IncomeMasterFormModal } from "../components/IncomeMasterFormModal.tsx"
import { Modal } from "../components/Modal.tsx"
import { rowActionButtonBaseClass as actionButtonBaseClass } from "../components/RowActionButtons.tsx"

const tabs = [
  { id: "expenses", label: "支出" },
  { id: "incomes", label: "収入" },
  { id: "categories", label: "カテゴリ" },
  { id: "payments", label: "支払方法" },
] as const

type TabId = (typeof tabs)[number]["id"]

export function MastersPage() {
  const [active, setActive] = useState<TabId>("expenses")

  return (
    <div className="space-y-4">
      <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <h2 className="mb-4 text-xl font-bold">支出・収入</h2>
        <nav className="flex flex-wrap gap-2">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActive(tab.id)}
              className={`rounded-full px-3 py-1.5 text-sm ${
                active === tab.id ? "bg-indigo-600 text-white" : "bg-slate-100 text-slate-600 hover:bg-slate-200"
              }`}
            >
              {tab.label}
            </button>
          ))}
        </nav>
      </section>

      {active === "categories" && <CategoriesSection />}
      {active === "payments" && <PaymentMethodsSection />}
      {active === "expenses" && <ExpenseMastersSection />}
      {active === "incomes" && <IncomeMastersSection />}
    </div>
  )
}

const KIND_LABEL: Record<CategoryKind, string> = {
  expense: "支出",
  income: "収入",
}

function toKindLabel(kind: string): string {
  if (kind === "expense") return KIND_LABEL.expense
  if (kind === "income") return KIND_LABEL.income
  return "不明"
}

function CategoriesSection() {
  const loader = useCallback(
    () => Promise.all([api.majorCategories(), api.minorCategories()]),
    [],
  )
  const result = useFetch(loader)
  const [openModal, setOpenModal] = useState<"major" | "minor" | null>(null)
  const [editingMajor, setEditingMajor] = useState<MajorCategory | null>(null)
  const [editingMinor, setEditingMinor] = useState<MinorCategory | null>(null)
  const [actionError, setActionError] = useState<string | null>(null)

  if (result.status === "loading") return <Loading label="カテゴリを読み込み中…" />
  if (result.status === "error") return <ErrorBox error={result.error} />

  const [majorsRaw, minorsRaw] = result.data
  const majors = sortMajorCategories(majorsRaw)
  const minors = sortMinorCategories(minorsRaw)
  const handleSaved = () => {
    setOpenModal(null)
    setEditingMajor(null)
    setEditingMinor(null)
    setActionError(null)
    result.refetch()
  }

  const onDeleteMajor = async (major: MajorCategory) => {
    if (!window.confirm(`大カテゴリ「${major.name}」を削除しますか？`)) return
    setActionError(null)
    try {
      await api.deleteMajorCategory(major.id)
      result.refetch()
    } catch (err) {
      setActionError(apiErrorMessage(err))
    }
  }

  const onDeleteMinor = async (minor: MinorCategory) => {
    if (!window.confirm(`小カテゴリ「${minor.name}」を削除しますか？`)) return
    setActionError(null)
    try {
      await api.deleteMinorCategory(minor.id)
      result.refetch()
    } catch (err) {
      setActionError(apiErrorMessage(err))
    }
  }

  const minorsByMajorId = new Map<number, MinorCategory[]>()
  for (const minor of minors) {
    const group = minorsByMajorId.get(minor.major_category.id)
    if (group) {
      group.push(minor)
    } else {
      minorsByMajorId.set(minor.major_category.id, [minor])
    }
  }

  return (
    <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
      <div className="mb-3 flex items-center justify-between">
        <h3 className="text-lg font-semibold">カテゴリ</h3>
        <div className="flex gap-2">
          <button
            type="button"
            onClick={() => setOpenModal("major")}
            className="rounded-lg border border-slate-300 px-3 py-1.5 text-sm hover:bg-slate-50"
          >
            ＋ 大カテゴリ
          </button>
          <button
            type="button"
            onClick={() => setOpenModal("minor")}
            className="rounded-lg bg-indigo-600 px-3 py-1.5 text-sm font-medium text-white hover:bg-indigo-500"
          >
            ＋ 小カテゴリ
          </button>
        </div>
      </div>

      {majors.length === 0 ? (
        <p className="text-sm text-slate-500">大カテゴリが未登録</p>
      ) : (
        <ul className="space-y-2">
          {majors.map((major: MajorCategory) => {
            const majorMinors = minorsByMajorId.get(major.id) ?? []
            return (
              <li key={major.id} className="rounded-lg border border-slate-200">
                <details open className="group">
                  <summary className="flex cursor-pointer list-none items-center justify-between px-3 py-2 text-sm">
                    <span className="font-medium">{major.name}</span>
                    <span className="flex items-center gap-2 text-xs text-slate-500">
                      <span>{toKindLabel(major.kind)}</span>
                      <span>{majorMinors.length}件</span>
                      <button
                        type="button"
                        className="rounded border border-slate-300 px-1.5 py-0.5 text-xs hover:bg-slate-100"
                        onClick={(e) => {
                          e.preventDefault()
                          setEditingMajor(major)
                        }}
                      >
                        編集
                      </button>
                      <button
                        type="button"
                        className="rounded border border-rose-300 px-1.5 py-0.5 text-xs text-rose-700 hover:bg-rose-50"
                        onClick={(e) => {
                          e.preventDefault()
                          void onDeleteMajor(major)
                        }}
                      >
                        削除
                      </button>
                    </span>
                  </summary>
                  <div className="border-t border-slate-100 px-3 py-2">
                    {majorMinors.length === 0 ? (
                      <p className="text-xs text-slate-400">小カテゴリなし</p>
                    ) : (
                      <ul className="space-y-1">
                        {majorMinors.map((minor) => (
                          <li key={minor.id} className="flex items-center justify-between rounded bg-slate-50 px-2 py-1 text-sm text-slate-700">
                            <span>{minor.name}</span>
                            <div className="flex items-center gap-2">
                              <button
                                type="button"
                                className="rounded border border-slate-300 px-2 py-1 text-xs hover:bg-white"
                                onClick={() => setEditingMinor(minor)}
                              >
                                編集
                              </button>
                              <button
                                type="button"
                                className="rounded border border-rose-300 px-2 py-1 text-xs text-rose-700 hover:bg-rose-50"
                                onClick={() => void onDeleteMinor(minor)}
                              >
                                削除
                              </button>
                            </div>
                          </li>
                        ))}
                      </ul>
                    )}
                  </div>
                </details>
              </li>
            )
          })}
        </ul>
      )}

      {openModal === "major" && (
        <MajorCategoryFormModal onClose={() => setOpenModal(null)} onSaved={handleSaved} />
      )}
      {openModal === "minor" && (
        <MinorCategoryFormModal
          onClose={() => setOpenModal(null)}
          onSaved={handleSaved}
          majors={majors}
        />
      )}
      {editingMajor && (
        <MajorCategoryFormModal onClose={() => setEditingMajor(null)} onSaved={handleSaved} initial={editingMajor} />
      )}
      {editingMinor && (
        <MinorCategoryFormModal
          onClose={() => setEditingMinor(null)}
          onSaved={handleSaved}
          majors={majors}
          initial={editingMinor}
        />
      )}
      {actionError && <p className="mt-3 text-sm text-rose-700">{actionError}</p>}
    </section>
  )
}

function PaymentMethodsSection() {
  const loader = useCallback(() => api.paymentMethods(), [])
  const result = useFetch(loader)
  const [open, setOpen] = useState(false)
  const [editing, setEditing] = useState<PaymentMethod | null>(null)
  const [actionError, setActionError] = useState<string | null>(null)

  if (result.status === "loading") return <Loading label="支払方法を読み込み中…" />
  if (result.status === "error") return <ErrorBox error={result.error} />

  const handleSaved = () => {
    setOpen(false)
    setEditing(null)
    setActionError(null)
    result.refetch()
  }

  const onDelete = async (method: PaymentMethod) => {
    if (!window.confirm(`支払方法「${method.name}」を削除しますか？`)) return
    setActionError(null)
    try {
      await api.deletePaymentMethod(method.id)
      result.refetch()
    } catch (err) {
      setActionError(apiErrorMessage(err))
    }
  }

  return (
    <Panel title="支払方法" actionLabel="＋ 追加" onAction={() => setOpen(true)}>
      {result.data.length === 0 ? (
        <p className="text-sm text-slate-500">支払方法が未登録</p>
      ) : (
        <Table
          head={["名前", "種別", "スケジュール", ""]}
          rows={result.data.map((method) => [
            method.name,
            formatPaymentMethodTypeLabel(method.method_type),
            formatPaymentMethodSchedule(method),
            <div key={`payment-actions-${method.id}`} className="flex items-center gap-1">
              <button
                type="button"
                className="rounded border border-slate-300 px-1.5 py-0.5 text-xs hover:bg-slate-50"
                onClick={() => setEditing(method)}
              >
                編集
              </button>
              <button
                type="button"
                className="rounded border border-rose-300 px-1.5 py-0.5 text-xs text-rose-700 hover:bg-rose-50"
                onClick={() => onDelete(method)}
              >
                削除
              </button>
            </div>,
          ])}
          emptyMessage="支払方法が未登録"
        />
      )}
      {actionError && <p className="mt-3 text-sm text-rose-700">{actionError}</p>}
      {open && <PaymentMethodFormModal onClose={() => setOpen(false)} onSaved={handleSaved} />}
      {editing && <PaymentMethodFormModal onClose={() => setEditing(null)} onSaved={handleSaved} initial={editing} />}
    </Panel>
  )
}

/** 大カテゴリ名順の折りたたみグループ（各行は小カテゴリ名順） */
function groupMastersByMajor<T extends { id: number; minor_category_id: number }>(
  rows: T[],
  minorMap: Map<number, MinorCategory>,
): { majorName: string; rows: T[] }[] {
  const byMajor = new Map<string, T[]>()
  for (const row of rows) {
    const minor = minorMap.get(row.minor_category_id)
    const majorName = minor?.major_category.name ?? "—"
    const list = byMajor.get(majorName) ?? []
    list.push(row)
    byMajor.set(majorName, list)
  }
  return [...byMajor.entries()]
    .sort(([a], [b]) => a.localeCompare(b, "ja"))
    .map(([majorName, list]) => ({
      majorName,
      rows: [...list].sort((r1, r2) => {
        const n1 = minorMap.get(r1.minor_category_id)?.name ?? ""
        const n2 = minorMap.get(r2.minor_category_id)?.name ?? ""
        const c = n1.localeCompare(n2, "ja")
        return c !== 0 ? c : r1.id - r2.id
      }),
    }))
}

function ExpenseMastersSection() {
  const loader = useCallback(
    () => Promise.all([api.expenses(), api.minorCategories(), api.paymentMethods()]),
    [],
  )
  const result = useFetch(loader)
  const [open, setOpen] = useState(false)
  const [editing, setEditing] = useState<ExpenseMaster | null>(null)
  const [detail, setDetail] = useState<ExpenseMaster | null>(null)
  const [actionError, setActionError] = useState<string | null>(null)
  const [filter, setFilter] = useState<"recurring" | "one_time">("one_time")

  const loadExpenseDetailActuals = useCallback(() => {
    if (detail == null) return Promise.resolve([] as MasterActual[])
    return api.expenseActuals(detail.id)
  }, [detail])

  if (result.status === "loading") return <Loading label="支出を読み込み中…" />
  if (result.status === "error") return <ErrorBox error={result.error} />

  const [expenses, minorsRaw, methods] = result.data
  const minors = sortMinorCategories(minorsRaw)
  const minorMap = buildMap(minors, (m) => m.id)
  const methodMap = buildMap(methods, (m) => m.id)
  const filteredExpenses = expenses.filter((row) => row.expense_type === filter)
  const handleSaved = () => {
    setOpen(false)
    setEditing(null)
    setActionError(null)
    result.refetch()
  }

  const onDelete = async (row: ExpenseMaster) => {
    if (!window.confirm("マスタと紐づく実績（台帳）もまとめて削除します。よろしいですか？")) return
    setActionError(null)
    try {
      await api.deleteExpense(row.id)
      result.refetch()
    } catch (err) {
      setActionError(apiErrorMessage(err))
    }
  }

  return (
    <Panel title="支出" actionLabel="＋ 実績を追加" onAction={() => setOpen(true)}>
      <TypeFilterTabs
        current={filter}
        onChange={setFilter}
      />
      {filteredExpenses.length === 0 ? (
        <p className="text-sm text-slate-500">条件に一致する支出がありません</p>
      ) : (
        <ul className="space-y-2">
          {groupMastersByMajor(filteredExpenses, minorMap).map(({ majorName, rows }) => (
            <li key={majorName} className="rounded-lg border border-slate-200">
              <details open className="group">
                <summary className="flex cursor-pointer list-none items-center justify-between gap-2 px-3 py-2 text-sm">
                  <span className="font-medium text-slate-800">{majorName}</span>
                  <span className="text-xs text-slate-500">{rows.length}件</span>
                </summary>
                <div className="overflow-x-auto border-t border-slate-100">
                  <table className="min-w-[820px] divide-y divide-slate-200 text-sm">
                    <thead className="bg-slate-50 text-left text-xs text-slate-500">
                      <tr>
                        <th className="px-3 py-2 whitespace-nowrap">小カテゴリ</th>
                        <th className="px-3 py-2 whitespace-nowrap">種別</th>
                        <th className="px-3 py-2 whitespace-nowrap">周期</th>
                        <th className="px-3 py-2 whitespace-nowrap">金額</th>
                        <th className="px-3 py-2 whitespace-nowrap">支払方法</th>
                        {filter === "one_time" ? (
                          <th className="px-3 py-2 whitespace-nowrap">支払月</th>
                        ) : (
                          <>
                            <th className="px-3 py-2 whitespace-nowrap">開始月</th>
                            <th className="px-3 py-2 whitespace-nowrap">終了月</th>
                          </>
                        )}
                        <th className="px-3 py-2" />
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100">
                      {rows.map((row) => (
                        <tr key={row.id}>
                          <td className="px-3 py-2 whitespace-nowrap text-slate-800">
                            {minorMap.get(row.minor_category_id)?.name ?? "—"}
                          </td>
                          <td className="px-3 py-2 whitespace-nowrap">{formatRecurringTypeLabel(row.expense_type)}</td>
                          <td className="px-3 py-2 whitespace-nowrap">{formatExpenseCycleCell(row)}</td>
                          <td className="px-3 py-2 whitespace-nowrap">{formatAmountCell(row.amount)}</td>
                          <td className="px-3 py-2 whitespace-nowrap">{methodMap.get(row.payment_method_id)?.name ?? "—"}</td>
                          {filter === "one_time" ? (
                            <td className="px-3 py-2 whitespace-nowrap">{formatMonthCell(row.start_month)}</td>
                          ) : (
                            <>
                              <td className="px-3 py-2 whitespace-nowrap">{formatMonthCell(row.start_month)}</td>
                              <td className="px-3 py-2 whitespace-nowrap">{row.end_month ? formatMonthCell(row.end_month) : "—"}</td>
                            </>
                          )}
                          <td className="px-3 py-2">
                            <div className="flex items-center gap-2 whitespace-nowrap">
                              <button
                                type="button"
                                className={`${actionButtonBaseClass} border-indigo-300 text-indigo-700 hover:bg-indigo-50`}
                                onClick={() => setDetail(row)}
                              >
                                詳細
                              </button>
                              <button
                                type="button"
                                className={`${actionButtonBaseClass} border-slate-300 text-slate-700 hover:bg-slate-50`}
                                onClick={() => setEditing(row)}
                              >
                                編集
                              </button>
                              <button
                                type="button"
                                className={`${actionButtonBaseClass} border-rose-300 text-rose-700 hover:bg-rose-50`}
                                onClick={() => onDelete(row)}
                              >
                                削除
                              </button>
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </details>
            </li>
          ))}
        </ul>
      )}
      {actionError && <p className="mt-3 text-sm text-rose-700">{actionError}</p>}
      {open && (
        <ExpenseMasterFormModal
          onClose={() => setOpen(false)}
          onSaved={handleSaved}
          minors={minors}
          paymentMethods={methods}
        />
      )}
      {editing && (
        <ExpenseMasterFormModal
          onClose={() => setEditing(null)}
          onSaved={handleSaved}
          minors={minors}
          paymentMethods={methods}
          initial={editing}
        />
      )}
      {detail && (
        <MasterActualsModal
          title={`支出実績: ${formatCategory(minorMap.get(detail.minor_category_id))}`}
          kind="expense"
          masterId={detail.id}
          masterMemo={detail.memo}
          loadActuals={loadExpenseDetailActuals}
          onClose={() => setDetail(null)}
        />
      )}
    </Panel>
  )
}

function IncomeMastersSection() {
  const loader = useCallback(
    () => Promise.all([api.incomes(), api.minorCategories()]),
    [],
  )
  const result = useFetch(loader)
  const [open, setOpen] = useState(false)
  const [editing, setEditing] = useState<IncomeMaster | null>(null)
  const [detail, setDetail] = useState<IncomeMaster | null>(null)
  const [actionError, setActionError] = useState<string | null>(null)
  const [filter, setFilter] = useState<"recurring" | "one_time">("one_time")

  const loadIncomeDetailActuals = useCallback(() => {
    if (detail == null) return Promise.resolve([] as MasterActual[])
    return api.incomeActuals(detail.id)
  }, [detail])

  if (result.status === "loading") return <Loading label="収入を読み込み中…" />
  if (result.status === "error") return <ErrorBox error={result.error} />

  const [incomes, minorsRaw] = result.data
  const minors = sortMinorCategories(minorsRaw)
  const minorMap = buildMap(minors, (m) => m.id)
  const filteredIncomes = incomes.filter((row) => row.income_type === filter)
  const handleSaved = () => {
    setOpen(false)
    setEditing(null)
    setActionError(null)
    result.refetch()
  }

  const onDelete = async (row: IncomeMaster) => {
    if (!window.confirm("マスタと紐づく実績（台帳）もまとめて削除します。よろしいですか？")) return
    setActionError(null)
    try {
      await api.deleteIncome(row.id)
      result.refetch()
    } catch (err) {
      setActionError(apiErrorMessage(err))
    }
  }

  return (
    <Panel title="収入" actionLabel="＋ 実績を追加" onAction={() => setOpen(true)}>
      <TypeFilterTabs
        current={filter}
        onChange={setFilter}
      />
      {filteredIncomes.length === 0 ? (
        <p className="text-sm text-slate-500">条件に一致する収入がありません</p>
      ) : (
        <ul className="space-y-2">
          {groupMastersByMajor(filteredIncomes, minorMap).map(({ majorName, rows }) => (
            <li key={majorName} className="rounded-lg border border-slate-200">
              <details open className="group">
                <summary className="flex cursor-pointer list-none items-center justify-between gap-2 px-3 py-2 text-sm">
                  <span className="font-medium text-slate-800">{majorName}</span>
                  <span className="text-xs text-slate-500">{rows.length}件</span>
                </summary>
                <div className="overflow-x-auto border-t border-slate-100">
                  <table className="min-w-[760px] divide-y divide-slate-200 text-sm">
                    <thead className="bg-slate-50 text-left text-xs text-slate-500">
                      <tr>
                        <th className="px-3 py-2 whitespace-nowrap">小カテゴリ</th>
                        <th className="px-3 py-2 whitespace-nowrap">種別</th>
                        <th className="px-3 py-2 whitespace-nowrap">金額</th>
                        <th className="px-3 py-2 whitespace-nowrap">開始月</th>
                        <th className="px-3 py-2 whitespace-nowrap">終了月</th>
                        <th className="px-3 py-2" />
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100">
                      {rows.map((row: IncomeMaster) => (
                        <tr key={row.id}>
                          <td className="px-3 py-2 whitespace-nowrap text-slate-800">
                            {minorMap.get(row.minor_category_id)?.name ?? "—"}
                          </td>
                          <td className="px-3 py-2 whitespace-nowrap">{formatRecurringTypeLabel(row.income_type)}</td>
                          <td className="px-3 py-2 whitespace-nowrap">{formatAmountCell(row.amount)}</td>
                          <td className="px-3 py-2 whitespace-nowrap">{formatMonthCell(row.start_month)}</td>
                          <td className="px-3 py-2 whitespace-nowrap">{row.end_month ? formatMonthCell(row.end_month) : "—"}</td>
                          <td className="px-3 py-2">
                            <div className="flex items-center gap-2 whitespace-nowrap">
                              <button
                                type="button"
                                className={`${actionButtonBaseClass} border-indigo-300 text-indigo-700 hover:bg-indigo-50`}
                                onClick={() => setDetail(row)}
                              >
                                詳細
                              </button>
                              <button
                                type="button"
                                className={`${actionButtonBaseClass} border-slate-300 text-slate-700 hover:bg-slate-50`}
                                onClick={() => setEditing(row)}
                              >
                                編集
                              </button>
                              <button
                                type="button"
                                className={`${actionButtonBaseClass} border-rose-300 text-rose-700 hover:bg-rose-50`}
                                onClick={() => onDelete(row)}
                              >
                                削除
                              </button>
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </details>
            </li>
          ))}
        </ul>
      )}
      {actionError && <p className="mt-3 text-sm text-rose-700">{actionError}</p>}
      {open && (
        <IncomeMasterFormModal
          onClose={() => setOpen(false)}
          onSaved={handleSaved}
          minors={minors}
        />
      )}
      {editing && (
        <IncomeMasterFormModal
          onClose={() => setEditing(null)}
          onSaved={handleSaved}
          minors={minors}
          initial={editing}
        />
      )}
      {detail && (
        <MasterActualsModal
          title={`収入実績: ${formatCategory(minorMap.get(detail.minor_category_id))}`}
          kind="income"
          masterId={detail.id}
          loadActuals={loadIncomeDetailActuals}
          onClose={() => setDetail(null)}
        />
      )}
    </Panel>
  )
}

function formatCategory(minor: MinorCategory | undefined): string {
  if (!minor) return "—"
  return `${minor.major_category.name} / ${minor.name}`
}

function formatMonthCell(date: string): string {
  return date.slice(0, 7).replace("-", "/")
}

/** 実績行の `month`（API の日付文字列）→ `<input type="month">` 用 */
function actualMonthToInput(isoMonth: string): string {
  return isoMonth.slice(0, 7)
}

function formatAmountCell(amount: string | number): string {
  const n = typeof amount === "string" ? Number(amount) : amount
  return Number.isFinite(n) ? `¥${n.toLocaleString("ja-JP")}` : "¥0"
}

function formatExpenseCycleCell(expense: ExpenseMaster): string {
  if (expense.expense_type !== "recurring") return "—"
  if (expense.recurring_cycle === "yearly") {
    return `${formatRecurringCycleLabel("yearly")} (${expense.renewal_month ?? "?"}月)`
  }
  return formatRecurringCycleLabel("monthly")
}

function TypeFilterTabs({
  current,
  onChange,
}: {
  current: "recurring" | "one_time"
  onChange: (value: "recurring" | "one_time") => void
}) {
  return (
    <div className="mb-3 inline-flex rounded-full bg-slate-100 p-0.5 text-xs">
      <FilterTab active={current === "one_time"} onClick={() => onChange("one_time")}>
        単発
      </FilterTab>
      <FilterTab active={current === "recurring"} onClick={() => onChange("recurring")}>
        定期
      </FilterTab>
    </div>
  )
}

function FilterTab({
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

function buildMap<T, K>(items: T[], keyOf: (item: T) => K): Map<K, T> {
  const map = new Map<K, T>()
  for (const item of items) {
    map.set(keyOf(item), item)
  }
  return map
}

function Panel({
  title,
  actionLabel,
  onAction,
  children,
}: {
  title: string
  actionLabel?: string
  onAction?: () => void
  children: React.ReactNode
}) {
  return (
    <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
      <div className="mb-3 flex items-center justify-between">
        <h3 className="text-lg font-semibold">{title}</h3>
        {actionLabel && (
          <button
            type="button"
            onClick={onAction}
            className="rounded-lg bg-indigo-600 px-3 py-1.5 text-sm font-medium text-white hover:bg-indigo-500"
          >
            {actionLabel}
          </button>
        )}
      </div>
      {children}
    </section>
  )
}

function Table({
  head,
  rows,
  emptyMessage = "データがありません",
}: {
  head: string[]
  rows: React.ReactNode[][]
  emptyMessage?: string
}) {
  if (rows.length === 0) {
    return <p className="text-sm text-slate-500">{emptyMessage}</p>
  }

  return (
    <div className="overflow-x-auto rounded-lg border border-slate-200">
      <table className="min-w-[640px] divide-y divide-slate-200 text-sm">
        <thead className="bg-slate-50 text-left text-xs text-slate-500">
          <tr>
            {head.map((label) => (
              <th key={label} className="px-3 py-2 whitespace-nowrap">
                {label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="divide-y divide-slate-100">
          {rows.map((row, i) => (
            <tr key={i}>
              {row.map((cell, j) => (
                <td key={j} className="px-3 py-2 whitespace-nowrap">
                  {cell}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

function MasterActualsModal({
  title,
  loadActuals,
  onClose,
  kind,
  masterId,
  masterMemo,
}: {
  title: string
  loadActuals: () => Promise<MasterActual[]>
  onClose: () => void
  kind: "expense" | "income"
  masterId: number
  /** 支出マスタのメモ（一覧では出さず詳細のみ） */
  masterMemo?: string | null
}) {
  const result = useFetch(loadActuals)
  const [rowError, setRowError] = useState<string | null>(null)
  const [deletingId, setDeletingId] = useState<number | null>(null)
  const [editingId, setEditingId] = useState<number | null>(null)
  const [editMonth, setEditMonth] = useState("")
  const [editAmount, setEditAmount] = useState("")
  const [savingEditId, setSavingEditId] = useState<number | null>(null)

  const cancelEdit = () => {
    setEditingId(null)
    setEditMonth("")
    setEditAmount("")
    setRowError(null)
  }

  const startEdit = (row: MasterActual) => {
    setRowError(null)
    setEditingId(row.transaction_id)
    setEditMonth(actualMonthToInput(row.month))
    setEditAmount(String(Math.round(Number(row.amount))))
  }

  const saveEdit = async (row: MasterActual) => {
    const amount = Math.round(Number(editAmount))
    if (!Number.isFinite(amount) || amount < 0) {
      setRowError("金額は0以上の数値で入力してください")
      return
    }
    setSavingEditId(row.transaction_id)
    setRowError(null)
    try {
      const monthIso = `${editMonth}-01`
      if (kind === "expense") {
        await api.updateExpenseActual(masterId, row.transaction_id, { month: monthIso, amount })
      } else {
        await api.updateIncomeActual(masterId, row.transaction_id, { month: monthIso, amount })
      }
      cancelEdit()
      result.refetch()
    } catch (err) {
      setRowError(apiErrorMessage(err))
    } finally {
      setSavingEditId(null)
    }
  }

  const onDeleteRow = async (row: MasterActual) => {
    if (
      !window.confirm(
        `この実績を削除しますか？\n${formatMonthCell(row.month)} / ${formatAmountCell(row.amount)}\n台帳の取引も削除されます。`,
      )
    ) {
      return
    }
    setRowError(null)
    setDeletingId(row.transaction_id)
    try {
      if (kind === "expense") {
        await api.deleteExpenseActual(masterId, row.transaction_id)
      } else {
        await api.deleteIncomeActual(masterId, row.transaction_id)
      }
      if (editingId === row.transaction_id) {
        cancelEdit()
      }
      result.refetch()
    } catch (err) {
      setRowError(apiErrorMessage(err))
    } finally {
      setDeletingId(null)
    }
  }

  return (
    <Modal title={title} onClose={onClose}>
      {kind === "expense" && masterMemo != null && masterMemo.trim() !== "" && (
        <div className="mb-4 rounded-lg border border-slate-200 bg-slate-50 px-3 py-2 text-sm">
          <p className="text-xs font-medium text-slate-500">マスタのメモ</p>
          <p className="mt-1 whitespace-pre-wrap text-slate-800">{masterMemo.trim()}</p>
        </div>
      )}
      {result.status === "loading" && <p className="text-sm text-slate-500">実績を読み込み中…</p>}
      {result.status === "error" && <p className="text-sm text-rose-700">{result.error.message}</p>}
      {rowError && <p className="mb-2 text-sm text-rose-700">{rowError}</p>}
      {result.status === "success" &&
        (result.data.length === 0 ? (
          <p className="text-sm text-slate-500">実績データがありません</p>
        ) : (
          <div className="overflow-hidden rounded-lg border border-slate-200">
            <table className="min-w-full divide-y divide-slate-200 text-sm">
              <thead className="bg-slate-50 text-left text-xs text-slate-500">
                <tr>
                  <th className="px-3 py-2">月</th>
                  <th className="px-3 py-2">金額（円）</th>
                  <th className="px-3 py-2" />
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {result.data.map((row) => (
                  <tr key={row.transaction_id}>
                    {editingId === row.transaction_id ? (
                      <>
                        <td className="px-3 py-2 align-middle">
                          <input
                            type="month"
                            value={editMonth}
                            onChange={(e) => setEditMonth(e.target.value)}
                            className="w-full max-w-44 rounded-md border border-slate-300 px-2 py-1 text-xs"
                          />
                        </td>
                        <td className="px-3 py-2 align-middle">
                          <input
                            type="number"
                            min={0}
                            step={1}
                            value={editAmount}
                            onChange={(e) => setEditAmount(e.target.value)}
                            className="w-full max-w-36 rounded-md border border-slate-300 px-2 py-1 text-xs"
                          />
                        </td>
                        <td className="px-3 py-2 text-right">
                          <div className="flex flex-wrap justify-end gap-1">
                            <button
                              type="button"
                              disabled={savingEditId === row.transaction_id}
                              onClick={() => void saveEdit(row)}
                              className="rounded-md bg-indigo-600 px-2 py-1 text-xs font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
                            >
                              {savingEditId === row.transaction_id ? "保存中…" : "保存"}
                            </button>
                            <button
                              type="button"
                              disabled={savingEditId === row.transaction_id}
                              onClick={cancelEdit}
                              className="rounded-md border border-slate-300 px-2 py-1 text-xs text-slate-700 hover:bg-slate-50 disabled:opacity-50"
                            >
                              キャンセル
                            </button>
                          </div>
                        </td>
                      </>
                    ) : (
                      <>
                        <td className="px-3 py-2">{formatMonthCell(row.month)}</td>
                        <td className="px-3 py-2">{formatAmountCell(row.amount)}</td>
                        <td className="px-3 py-2 text-right">
                          <div className="flex flex-wrap justify-end gap-1">
                            <button
                              type="button"
                              disabled={
                                deletingId === row.transaction_id ||
                                savingEditId != null ||
                                (editingId != null && editingId !== row.transaction_id)
                              }
                              onClick={() => startEdit(row)}
                              className="rounded-md border border-indigo-300 px-2 py-1 text-xs font-medium text-indigo-700 hover:bg-indigo-50 disabled:cursor-not-allowed disabled:opacity-50"
                            >
                              編集
                            </button>
                            <button
                              type="button"
                              disabled={editingId != null || deletingId === row.transaction_id}
                              onClick={() => void onDeleteRow(row)}
                              className="rounded-md border border-rose-300 px-2 py-1 text-xs font-medium text-rose-700 hover:bg-rose-50 disabled:cursor-not-allowed disabled:opacity-50"
                            >
                              {deletingId === row.transaction_id ? "削除中…" : "削除"}
                            </button>
                          </div>
                        </td>
                      </>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ))}
    </Modal>
  )
}

function Loading({ label }: { label: string }) {
  return (
    <div className="rounded-2xl border border-slate-200 bg-white p-5 text-sm text-slate-500 shadow-sm">{label}</div>
  )
}

function ErrorBox({ error }: { error: Error }) {
  return (
    <div className="rounded-2xl border border-rose-200 bg-rose-50 p-5 text-sm text-rose-700 shadow-sm">
      <p className="font-semibold">読み込みに失敗しました</p>
      <p className="mt-1 text-xs text-rose-600">{error.message}</p>
    </div>
  )
}
