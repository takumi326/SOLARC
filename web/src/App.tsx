import { useEffect, useState } from "react"
import { NavLink, Navigate, Route, Routes } from "react-router-dom"
import { api } from "./lib/api.ts"
import { verifyAuthWithRetry, waitForApiReady } from "./lib/apiReady.ts"
import { isSupabaseConfigured, supabase } from "./lib/supabase.ts"
import { LoginPage } from "./pages/LoginPage.tsx"
import { FinanceSummaryPage } from "./pages/FinanceSummaryPage.tsx"
import { MastersPage } from "./pages/MastersPage.tsx"
import { SettingsPage } from "./pages/SettingsPage.tsx"
import { StockDailyPage } from "./pages/StockDailyPage.tsx"
import { StocksListPage } from "./pages/StocksListPage.tsx"
import { StockDetailPage } from "./pages/StockDetailPage.tsx"
import { StockTradesPage } from "./pages/StockTradesPage.tsx"

type SidebarNavItem = { to: string; label: string }

const sidebarNavGroups: { label: string; items: SidebarNavItem[] }[] = [
  {
    label: "収支管理",
    items: [
      { to: "/finance", label: "今年度サマリ" },
      { to: "/finance/masters", label: "支出・収入" },
      { to: "/finance/settings", label: "設定" },
    ],
  },
  {
    label: "株管理",
    items: [
      { to: "/stocks/daily", label: "毎日の記録" },
      { to: "/stocks", label: "株一覧" },
      { to: "/stocks/trades/real", label: "実取引一覧" },
      { to: "/stocks/trades/virtual-human", label: "仮想取引一覧" },
    ],
  },
]
const IS_DEV = import.meta.env.DEV

type InitialAuth = {
  status: "loading" | "authenticated" | "guest"
  error: string | null
}

const INITIAL_AUTH: InitialAuth = resolveInitialAuth()

export default function App() {
  const [drawerOpen, setDrawerOpen] = useState(false)
  const [authStatus, setAuthStatus] = useState<"loading" | "authenticated" | "guest">(
    IS_DEV ? "authenticated" : INITIAL_AUTH.status,
  )
  const [authError, setAuthError] = useState<string | null>(INITIAL_AUTH.error)
  const [loadingMessage, setLoadingMessage] = useState("認証を確認中…")
  const closeDrawer = () => setDrawerOpen(false)

  useEffect(() => {
    if (IS_DEV) return
    if (!supabase) return
    const client = supabase

    let active = true
    const verify = async () => {
      try {
        const { data } = await client.auth.getSession()
        if (!active) return
        if (!data.session?.access_token) {
          setAuthError(null)
          setAuthStatus("guest")
          return
        }
        setAuthStatus("loading")
        setLoadingMessage("サーバーを起動しています…")
        await waitForApiReady({ shouldContinue: () => active })
        if (!active) return
        setLoadingMessage("認証を確認中…")
        await verifyAuthWithRetry(() => api.me(), { shouldContinue: () => active })
        if (!active) return
        setAuthError(null)
        setAuthStatus("authenticated")
      } catch {
        if (!active) return
        setAuthError("ログインできませんでした")
        setAuthStatus("guest")
      }
    }

    void verify()
    const { data: listener } = client.auth.onAuthStateChange(() => {
      void verify()
    })

    return () => {
      active = false
      listener.subscription.unsubscribe()
    }
  }, [])

  if (authStatus === "loading") {
    return (
      <div className="mx-auto flex min-h-screen w-full max-w-7xl items-center justify-center p-6 text-slate-600">
        {loadingMessage}
      </div>
    )
  }

  if (authStatus === "guest") {
    return <LoginPage errorMessage={authError ?? undefined} />
  }

  return (
    <div className="mx-auto min-h-screen w-full max-w-7xl p-4 text-slate-800 sm:p-6">
      <header className="mb-4 flex items-center gap-3 lg:hidden">
        <button
          type="button"
          aria-label="メニューを開く"
          onClick={() => setDrawerOpen(true)}
          className="inline-flex h-9 w-9 items-center justify-center rounded-lg border border-slate-300 bg-white shadow-sm hover:bg-slate-50"
        >
          <span className="sr-only">メニュー</span>
          <span aria-hidden="true" className="text-lg leading-none">≡</span>
        </button>
        <h1 className="text-base font-bold">SOLARC</h1>
      </header>

      <div className="grid gap-4 lg:grid-cols-[220px_1fr] lg:items-start">
        <aside className="hidden rounded-2xl border border-slate-200 bg-white p-4 shadow-sm lg:sticky lg:top-6 lg:block lg:h-[calc(100vh-3rem)] lg:overflow-y-auto">
          <SidebarHeader />
          <SidebarNav onNavigate={closeDrawer} />
        </aside>

        <section className="min-w-0">
          <Routes>
            <Route path="/" element={<Navigate to="/finance" replace />} />
            <Route path="/finance" element={<FinanceSummaryPage />} />
            <Route path="/masters" element={<Navigate to="/finance/masters" replace />} />
            <Route path="/settings" element={<Navigate to="/finance/settings" replace />} />
            <Route path="/finance/masters" element={<MastersPage />} />
            <Route path="/finance/settings" element={<SettingsPage />} />
            <Route path="/stocks/daily" element={<StockDailyPage />} />
            <Route path="/stocks/trades/real" element={<StockTradesPage mode="real" />} />
            <Route path="/stocks/trades/virtual-human" element={<StockTradesPage mode="virtual-human" />} />
            <Route path="/stocks/:id" element={<StockDetailPage />} />
            <Route path="/stocks" element={<StocksListPage />} />
          </Routes>
        </section>
      </div>

      {drawerOpen && (
        <div className="fixed inset-0 z-40 flex lg:hidden">
          <div
            className="absolute inset-0 bg-slate-900/40"
            onClick={closeDrawer}
            aria-hidden="true"
          />
          <aside className="relative z-10 flex h-full w-64 flex-col bg-white p-4 shadow-xl">
            <div className="mb-3 flex items-center justify-between">
              <SidebarHeader />
              <button
                type="button"
                aria-label="メニューを閉じる"
                onClick={closeDrawer}
                className="text-2xl leading-none text-slate-400 hover:text-slate-600"
              >
                ×
              </button>
            </div>
            <SidebarNav onNavigate={closeDrawer} />
          </aside>
        </div>
      )}
    </div>
  )
}

function SidebarHeader() {
  return (
    <div>
      <h1 className="mb-4 text-lg font-bold">SOLARC</h1>
    </div>
  )
}

function SidebarNav({ onNavigate }: { onNavigate: () => void }) {
  return (
    <nav className="space-y-4">
      {sidebarNavGroups.map((group) => (
        <div key={group.label}>
          <p className="mb-1 px-2 text-xs font-semibold tracking-wide text-slate-400">{group.label}</p>
          <div className="space-y-1">
            {group.items.map((item) => (
              <SidebarNavLink key={item.to} item={item} onNavigate={onNavigate} />
            ))}
          </div>
        </div>
      ))}
    </nav>
  )
}

function SidebarNavLink({ item, onNavigate }: { item: SidebarNavItem; onNavigate: () => void }) {
  return (
    <NavLink
      to={item.to}
      end={item.to === "/finance" || item.to === "/stocks"}
      onClick={onNavigate}
      className={({ isActive }) =>
        `block rounded-lg px-3 py-2 text-sm ${
          isActive ? "bg-indigo-600 text-white" : "text-slate-600 hover:bg-slate-100"
        }`
      }
    >
      {item.label}
    </NavLink>
  )
}

function resolveInitialAuth(): InitialAuth {
  if (!IS_DEV && !isSupabaseConfigured) {
    return {
      status: "guest",
      error: "Supabase の設定が不足しています",
    }
  }

  return {
    status: "loading",
    error: null,
  }
}
