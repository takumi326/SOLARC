import { useCallback, useState } from "react"
import { api, type AiScriptRow } from "../lib/api.ts"
import { apiErrorMessage } from "../lib/errors.ts"
import { useFetch } from "../lib/useFetch.ts"
import { Modal, FormError, FieldLabel } from "../components/Modal.tsx"
import { RowActionButtons } from "../components/RowActionButtons.tsx"

type ModalState = null | { kind: "new" } | { kind: "view" | "edit"; row: AiScriptRow }

export function AiScriptsPage() {
  const loader = useCallback(() => api.aiScripts(), [])
  const result = useFetch(loader)
  const [modal, setModal] = useState<ModalState>(null)

  const deleteScript = async (row: AiScriptRow) => {
    if (!window.confirm("削除しますか？紐づく取引の参照が外れます。")) return
    try {
      await api.deleteAiScript(row.id)
      result.refetch()
    } catch (e) {
      window.alert(apiErrorMessage(e))
    }
  }

  if (result.status === "loading") return <p className="text-slate-600">読み込み中…</p>
  if (result.status === "error") return <p className="text-rose-600">{result.error.message}</p>

  const rows = result.data

  return (
    <div className="space-y-4">
      <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <div className="mb-4 flex items-center justify-between gap-2">
          <h2 className="text-xl font-bold">AI スクリプト一覧</h2>
          <button
            type="button"
            onClick={() => setModal({ kind: "new" })}
            className="rounded-lg bg-indigo-600 px-3 py-1.5 text-sm text-white hover:bg-indigo-500"
          >
            新規
          </button>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full text-left text-sm">
            <thead>
              <tr className="border-b border-slate-200 text-slate-500">
                <th className="py-2 pr-3">バージョン</th>
                <th className="py-2 pr-3">操作</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.id} className="border-b border-slate-100">
                  <td className="py-2 pr-3 font-medium">{r.version_name}</td>
                  <td className="py-2 pr-3">
                    <RowActionButtons
                      onDetail={() => setModal({ kind: "view", row: r })}
                      onEdit={() => setModal({ kind: "edit", row: r })}
                      onDelete={() => void deleteScript(r)}
                    />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {rows.length === 0 && <p className="py-6 text-center text-slate-500">まだ登録がありません</p>}
        </div>
      </section>

      {modal?.kind === "new" && (
        <AiScriptFormModal
          existing={null}
          onClose={() => setModal(null)}
          onSaved={() => {
            setModal(null)
            result.refetch()
          }}
        />
      )}
      {modal && modal.kind !== "new" && (
        <AiScriptFormModal
          existing={modal.row}
          readOnly={modal.kind === "view"}
          onClose={() => setModal(null)}
          onSaved={() => {
            setModal(null)
            result.refetch()
          }}
          onEdit={modal.kind === "view" ? () => setModal({ kind: "edit", row: modal.row }) : undefined}
        />
      )}
    </div>
  )
}

function AiScriptFormModal({
  existing,
  readOnly = false,
  onClose,
  onSaved,
  onEdit,
}: {
  existing: AiScriptRow | null
  readOnly?: boolean
  onClose: () => void
  onSaved: () => void
  onEdit?: () => void
}) {
  const [versionName, setVersionName] = useState(existing?.version_name ?? "")
  const [prompt, setPrompt] = useState(existing?.prompt ?? "")
  const [err, setErr] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  const title = readOnly ? "AI スクリプト詳細" : existing ? "AI スクリプトを編集" : "AI スクリプトを追加"
  const fieldClass = readOnly
    ? "rounded-lg bg-slate-50 px-2 py-1.5 text-slate-800"
    : "rounded-lg border border-slate-300 px-2 py-1.5"

  const save = async (e: React.FormEvent) => {
    e.preventDefault()
    if (readOnly) return
    setSaving(true)
    setErr(null)
    try {
      if (existing) {
        await api.updateAiScript(existing.id, {
          version_name: versionName,
          prompt: prompt || null,
        })
      } else {
        await api.createAiScript({
          version_name: versionName,
          prompt: prompt || null,
        })
      }
      onSaved()
    } catch (e) {
      setErr(apiErrorMessage(e))
    } finally {
      setSaving(false)
    }
  }

  return (
    <Modal title={title} onClose={onClose} size="lg">
      {!readOnly && (
        <p className="mb-3 text-sm text-slate-600">
          仮想取引（AI）のバージョン管理用です。銘柄詳細や取引一覧の「仮想・AI」で、このスクリプトを選んで記録を分けます。
        </p>
      )}
      <form onSubmit={(e) => void save(e)} className="space-y-3 text-sm">
        <label className="flex flex-col gap-1">
          <FieldLabel>バージョン名（一意）</FieldLabel>
          {readOnly ? (
            <p className={fieldClass}>{versionName}</p>
          ) : (
            <>
              <input
                value={versionName}
                onChange={(e) => setVersionName(e.target.value)}
                placeholder="例: v2.0"
                className={fieldClass}
                required
              />
              <span className="text-xs text-slate-500">同じ名前は登録できません。一覧で選ぶときの表示名になります。</span>
            </>
          )}
        </label>
        <label className="flex flex-col gap-1">
          <FieldLabel>プロンプト</FieldLabel>
          {readOnly ? (
            <p className={`${fieldClass} whitespace-pre-wrap font-mono text-xs`}>{prompt || "（未入力）"}</p>
          ) : (
            <>
              <textarea
                value={prompt}
                onChange={(e) => setPrompt(e.target.value)}
                placeholder="このバージョンで AI に渡すプロンプト全文"
                className="min-h-48 rounded-lg border border-slate-300 px-2 py-1.5 font-mono text-xs"
              />
              <span className="text-xs text-slate-500">仮想取引（AI）の判断根拠として保存するテキストです。</span>
            </>
          )}
        </label>
        <FormError message={err} />
        <div className="flex justify-end gap-2 pt-2">
          {readOnly ? (
            <>
              <button type="button" onClick={onClose} className="rounded-lg border border-slate-300 px-3 py-2 text-sm">
                閉じる
              </button>
              {onEdit && (
                <button
                  type="button"
                  onClick={onEdit}
                  className="rounded-lg bg-indigo-600 px-3 py-2 text-sm text-white hover:bg-indigo-500"
                >
                  編集
                </button>
              )}
            </>
          ) : (
            <>
              <button type="button" onClick={onClose} className="rounded-lg border border-slate-300 px-3 py-2 text-sm">
                キャンセル
              </button>
              <button type="submit" disabled={saving} className="rounded-lg bg-indigo-600 px-3 py-2 text-sm text-white disabled:opacity-60">
                {saving ? "保存中…" : "保存"}
              </button>
            </>
          )}
        </div>
      </form>
    </Modal>
  )
}
