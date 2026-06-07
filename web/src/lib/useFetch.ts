import { useCallback, useEffect, useState } from "react"

type State<T> =
  | { status: "loading"; data: null; error: null; refetch: () => void }
  | { status: "success"; data: T; error: null; refetch: () => void }
  | { status: "error"; data: null; error: Error; refetch: () => void }

type InternalState<T> =
  | { status: "loading"; data: null; error: null }
  | { status: "success"; data: T; error: null }
  | { status: "error"; data: null; error: Error }

export function useFetch<T>(loader: () => Promise<T>): State<T> {
  const [reloadKey, setReloadKey] = useState(0)
  const [state, setState] = useState<InternalState<T>>({ status: "loading", data: null, error: null })

  const refetch = useCallback(() => {
    setReloadKey((k) => k + 1)
  }, [])

  useEffect(() => {
    let cancelled = false

    loader()
      .then((data) => {
        if (cancelled) {
          console.log("CANCELLED loader:", loader.toString().slice(0, 50), data)
          return
        }
        setState({ status: "success", data, error: null })
      })
      .catch((error: unknown) => {
        if (cancelled) return
        const err = error instanceof Error ? error : new Error(String(error))
        setState({ status: "error", data: null, error: err })
      })

    return () => {
      cancelled = true
    }
  }, [loader, reloadKey])

  return { ...state, refetch } as State<T>
}
