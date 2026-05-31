import { useEffect } from "react"
import { warmUpApiInBackground } from "../lib/apiReady.ts"
import { supabase } from "../lib/supabase.ts"

type Props = {
  errorMessage?: string
}

export function LoginPage({ errorMessage }: Props) {
  useEffect(() => {
    warmUpApiInBackground()
  }, [])

  const startGoogleLogin = async () => {
    if (!supabase) return
    await supabase.auth.signInWithOAuth({
      provider: "google",
      options: {
        redirectTo: `${window.location.origin}${import.meta.env.BASE_URL.replace(/\/$/, "")}/`,
        // ログアウト後も前アカウントに自動で入らず、Google のアカウント選択を出す
        queryParams: { prompt: "select_account" },
      },
    })
  }

  return (
    <div className="mx-auto flex min-h-screen w-full max-w-md items-center p-4 sm:p-6">
      <section className="w-full rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
        <p className="text-sm font-semibold tracking-wide text-indigo-700">SOLARC</p>
        <h1 className="mt-1 text-xl font-bold text-slate-800">ログイン</h1>
        <div className="mt-4 space-y-3">
          {errorMessage && <p className="rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700">{errorMessage}</p>}
          <button
            type="button"
            onClick={() => void startGoogleLogin()}
            className="w-full rounded-lg bg-indigo-600 px-3 py-2 text-sm font-medium text-white hover:bg-indigo-500"
          >
            Googleでログイン
          </button>
        </div>
      </section>
    </div>
  )
}
