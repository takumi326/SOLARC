import { ApiError } from "./api.ts"

const API_BASE_URL = (import.meta.env.VITE_API_BASE_URL ?? "").replace(/\/+$/, "")

const DEFAULT_MAX_WAIT_MS = 120_000
const DEFAULT_INTERVAL_MS = 2_000
const DEFAULT_PING_TIMEOUT_MS = 15_000

export function isRetriableConnectionError(err: unknown): boolean {
  if (err instanceof ApiError) {
    return err.status === 408 || err.status === 429 || err.status >= 502
  }
  if (err instanceof DOMException && err.name === "AbortError") return true
  if (err instanceof TypeError) return true
  return false
}

async function pingHealth(timeoutMs: number): Promise<boolean> {
  if (!API_BASE_URL) return true

  const controller = new AbortController()
  const timeoutId = window.setTimeout(() => controller.abort(), timeoutMs)
  try {
    const response = await fetch(`${API_BASE_URL}/up`, {
      method: "GET",
      signal: controller.signal,
      headers: { Accept: "text/html,application/json" },
    })
    return response.ok
  } catch {
    return false
  } finally {
    window.clearTimeout(timeoutId)
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => {
    window.setTimeout(resolve, ms)
  })
}

type WaitForApiReadyOptions = {
  maxWaitMs?: number
  intervalMs?: number
  pingTimeoutMs?: number
  shouldContinue?: () => boolean
}

/** Render などコールドスタンバイの API が /up で応答するまで待つ */
export async function waitForApiReady(options?: WaitForApiReadyOptions): Promise<void> {
  if (!API_BASE_URL || import.meta.env.DEV) return

  const maxWaitMs = options?.maxWaitMs ?? DEFAULT_MAX_WAIT_MS
  const intervalMs = options?.intervalMs ?? DEFAULT_INTERVAL_MS
  const pingTimeoutMs = options?.pingTimeoutMs ?? DEFAULT_PING_TIMEOUT_MS
  const shouldContinue = options?.shouldContinue ?? (() => true)

  const deadline = Date.now() + maxWaitMs
  while (Date.now() < deadline) {
    if (!shouldContinue()) return
    if (await pingHealth(pingTimeoutMs)) return
    if (!shouldContinue()) return
    await sleep(intervalMs)
  }

  if (await pingHealth(pingTimeoutMs)) return
  throw new Error("api_unavailable")
}

/** ログイン画面表示中に API を起こしておく（失敗は無視） */
export function warmUpApiInBackground(): void {
  if (!API_BASE_URL || import.meta.env.DEV) return
  void waitForApiReady().catch(() => undefined)
}

type VerifyAuthOptions = {
  maxAttempts?: number
  shouldContinue?: () => boolean
}

/** 接続系エラー時のみ api.me 相当を再試行する */
export async function verifyAuthWithRetry<T>(
  request: () => Promise<T>,
  options?: VerifyAuthOptions,
): Promise<T> {
  const maxAttempts = options?.maxAttempts ?? 5
  const shouldContinue = options?.shouldContinue ?? (() => true)

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    if (!shouldContinue()) {
      throw new Error("aborted")
    }
    try {
      return await request()
    } catch (err) {
      if (!isRetriableConnectionError(err) || attempt === maxAttempts - 1) {
        throw err
      }
      await waitForApiReady({
        maxWaitMs: 30_000,
        shouldContinue,
      })
    }
  }

  throw new Error("api_unavailable")
}
