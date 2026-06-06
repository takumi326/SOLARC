import { useEffect, useState } from "react"
import { api } from "../lib/api.ts"
import { apiErrorMessage, apiErrorMessageWithFetchHint } from "../lib/errors.ts"
import {
  DEFAULT_IMPORT_PROMPT_TEMPLATE,
  IMPORT_PROMPT_PLACEHOLDERS,
  takeLegacyImportPromptFromLocalStorage,
  validateImportPromptTemplate,
} from "../lib/importPromptSettings.ts"
import { supabase } from "../lib/supabase.ts"

export function SettingsPage() {
  const [signingOut, setSigningOut] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [importPromptDraft, setImportPromptDraft] = useState(DEFAULT_IMPORT_PROMPT_TEMPLATE)
  const [importPromptLoading, setImportPromptLoading] = useState(true)
  const [importPromptSaving, setImportPromptSaving] = useState(false)
  const [importPromptSaved, setImportPromptSaved] = useState<string | null>(null)
  const [importPromptError, setImportPromptError] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    void (async () => {
      setImportPromptLoading(true)
      setImportPromptError(null)
      try {
        const remote = await api.userPreferences()
        if (cancelled) return
        let template = remote.import_claude_prompt_template
        const legacy = takeLegacyImportPromptFromLocalStorage()
        if (template == null && legacy != null && validateImportPromptTemplate(legacy) == null) {
          await api.updateUserPreferences({ import_claude_prompt_template: legacy })
          template = legacy
        }
        setImportPromptDraft(template ?? DEFAULT_IMPORT_PROMPT_TEMPLATE)
      } catch (err) {
        if (!cancelled) {
          setImportPromptError(apiErrorMessageWithFetchHint(err))
          setImportPromptDraft(DEFAULT_IMPORT_PROMPT_TEMPLATE)
        }
      } finally {
        if (!cancelled) setImportPromptLoading(false)
      }
    })()
    return () => {
      cancelled = true
    }
  }, [])

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

  const saveImportPrompt = async () => {
    setImportPromptError(null)
    setImportPromptSaved(null)
    const err = validateImportPromptTemplate(importPromptDraft)
    if (err) {
      setImportPromptError(err)
      return
    }
    setImportPromptSaving(true)
    try {
      const normalized = importPromptDraft.replace(/\r\n/g, "\n").trimEnd()
      const defaultNorm = DEFAULT_IMPORT_PROMPT_TEMPLATE.replace(/\r\n/g, "\n").trimEnd()
      if (normalized === defaultNorm) {
        await api.updateUserPreferences({ import_claude_prompt_template: null })
        setImportPromptDraft(DEFAULT_IMPORT_PROMPT_TEMPLATE)
        setImportPromptSaved("既定のプロンプトと同じ内容のため、サーバー上のカスタムを解除しました。")
      } else {
        await api.updateUserPreferences({ import_claude_prompt_template: normalized })
        setImportPromptSaved("保存しました。取込モーダルに反映されます。")
      }
      window.setTimeout(() => setImportPromptSaved(null), 4000)
    } catch (e) {
      setImportPromptError(apiErrorMessage(e))
    } finally {
      setImportPromptSaving(false)
    }
  }

  return (
    <div className="space-y-4">
      <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <h2 className="text-xl font-bold">設定</h2>
      </section>

      <section id="import-prompt" className="scroll-mt-4 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <h3 className="text-lg font-semibold">実績取込（Claude 用プロンプト）</h3>
        <p className="mt-1 text-xs text-slate-500">
          ダッシュボードの「取込」からコピーする Claude 向け指示文です。次のプレースホルダを必ず含めてください（保存時にチェックします）。
        </p>
        <ul className="mt-2 list-inside list-disc text-xs text-slate-600">
          <li>
            <code className="rounded bg-slate-100 px-1">{IMPORT_PROMPT_PLACEHOLDERS.CATALOG}</code>{" "}
            … 支出の小カテゴリ一覧（id と名前）
          </li>
          <li>
            <code className="rounded bg-slate-100 px-1">{IMPORT_PROMPT_PLACEHOLDERS.PAYMENT_METHOD_NAME}</code>{" "}
            … 固定で使う支払方法の表示名（取込処理は「Amazonカード」名のマスタに紐づけます）
          </li>
          <li>
            <code className="rounded bg-slate-100 px-1">{IMPORT_PROMPT_PLACEHOLDERS.EXAMPLE_MINOR_ID}</code>{" "}
            … 例の JSON に使う小カテゴリ id（数値）
          </li>
          <li>
            <code className="rounded bg-slate-100 px-1">{IMPORT_PROMPT_PLACEHOLDERS.MONTH}</code>{" "}
            … 取込対象の利用月 YYYY年MM月（取込モーダルで月が未指定のときはコピー時点の暦月）
          </li>
        </ul>
        <label className="mt-3 block text-sm">
          <span className="text-slate-700">プロンプト本文</span>
          <textarea
            value={importPromptDraft}
            onChange={(e) => setImportPromptDraft(e.target.value)}
            rows={18}
            spellCheck={false}
            disabled={importPromptLoading}
            className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 font-mono text-xs leading-relaxed disabled:bg-slate-50"
          />
        </label>
        <div className="mt-3 flex flex-wrap gap-2">
          <button
            type="button"
            onClick={() => void saveImportPrompt()}
            disabled={importPromptLoading || importPromptSaving}
            className="rounded-lg bg-indigo-600 px-3 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:cursor-not-allowed disabled:bg-indigo-300"
          >
            {importPromptSaving ? "保存中…" : "保存"}
          </button>
        </div>
        {importPromptError && (
          <p className="mt-2 whitespace-pre-line text-sm text-rose-700">{importPromptError}</p>
        )}
        {importPromptSaved && <p className="mt-2 text-sm text-emerald-700">{importPromptSaved}</p>}
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
