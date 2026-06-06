import { ApiError } from "./api.ts"

export function apiErrorMessage(err: unknown): string {
  if (err instanceof ApiError) {
    if (err.details) {
      const detail = Object.entries(err.details)
        .map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(", ") : v}`)
        .join(" / ")
      if (detail) return detail
    }
    return err.message
  }
  return err instanceof Error ? err.message : String(err)
}

function viteApiBaseUrlSet(): boolean {
  return Boolean((import.meta.env.VITE_API_BASE_URL ?? "").toString().trim())
}

/** 本番で API が 404 のとき、相対 /api ミス設定の可能性を追記する */
export function apiErrorMessageWithFetchHint(err: unknown): string {
  const base = apiErrorMessage(err)
  if (
    err instanceof ApiError &&
    err.status === 404 &&
    import.meta.env.PROD &&
    !viteApiBaseUrlSet()
  ) {
    return `${base}

Web を API と別ホスト（例: Vercel + Render）で出している場合、ビルド時に VITE_API_BASE_URL に API のオリジン（例: https://your-api.onrender.com、末尾スラッシュなし）を必ず設定してください。未設定だとブラウザがフロントと同じ URL に /api を送り、静的ホストが 404 を返します。

同一オリジンで /api をリバースプロキシしている場合は、API を最新にデプロイし /api/preferences/import_prompt（旧: /api/user_preferences）が存在するか確認してください。`
  }
  return base
}
