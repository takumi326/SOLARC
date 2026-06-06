import { useState } from "react"
import { api } from "../lib/api.ts"
import { apiErrorMessage } from "../lib/errors.ts"
import { supabase } from "../lib/supabase.ts"

export function SettingsPage() {
  const [signingOut, setSigningOut] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  const onSignOut = async () => {
    setSigningOut(true)
    setErrorMessage(null)
    try {
      await Promise.all([
        api.signOut(),
        supabase?.auth.signOut(),
      ])
      // このまま reload すると /finance/settings 等で再読み込みされ、ホスティング側が SPA 未対応だと 404 になる
      window.location.replace(import.meta.env.BASE_URL)
    } catch (error) {
      setErrorMessage(apiErrorMessage(error))
    } finally {
      setSigningOut(false)
    }
  }

  return (
    <div className="space-y-4">
      <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <h2 className="text-xl font-bold">設定</h2>
      </section>

      <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <h3 className="text-lg font-semibold">アカウント</h3>
        <p className="mt-1 text-xs text-slate-500">Google OAuth 連携（MVP予定）</p>
        <button
          type="button"
          onClick={() => void onSignOut()}
          disabled={signingOut}
          className="mt-3 rounded-lg border border-slate-300 px-3 py-2 text-sm disabled:cursor-not-allowed disabled:bg-slate-100"
        >
          {signingOut ? "処理中…" : "サインアウト"}
        </button>
        {errorMessage && <p className="mt-2 text-sm text-rose-700">{errorMessage}</p>}
      </section>
    </div>
  )
}
