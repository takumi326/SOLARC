import { useEffect, useRef, type ReactNode } from "react"

type Props = {
  title: string
  /** タイトル直後（毎日の記録の「プロンプト編集」など） */
  titleAside?: ReactNode
  onClose: () => void
  children: ReactNode
  size?: "sm" | "md" | "lg" | "xl" | "2xl"
}

const MODAL_MAX: Record<NonNullable<Props["size"]>, string> = {
  sm: "max-w-sm",
  md: "max-w-xl",
  lg: "max-w-4xl",
  xl: "max-w-6xl",
  /** 株の詳細など、PC で横幅を多く取りたいモーダル用 */
  "2xl": "max-w-[min(92rem,calc(100vw-2rem))]",
}

export function Modal({ title, titleAside, onClose, children, size = "md" }: Props) {
  /** オーバーレイ上で pointerdown したときだけ true。内側で押して外で離すと閉じないようにする */
  const overlayCloseArmed = useRef(false)

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose()
    }
    window.addEventListener("keydown", onKey)
    return () => window.removeEventListener("keydown", onKey)
  }, [onClose])

  return (
    <div
      className="fixed inset-0 z-30 flex items-center justify-center bg-slate-900/40 p-4"
      onPointerDown={(e) => {
        overlayCloseArmed.current = e.target === e.currentTarget
      }}
      onPointerUp={(e) => {
        if (e.target === e.currentTarget && overlayCloseArmed.current) {
          onClose()
        }
        overlayCloseArmed.current = false
      }}
      onPointerCancel={() => {
        overlayCloseArmed.current = false
      }}
    >
      <div className={`w-full ${MODAL_MAX[size]} max-h-[90vh] overflow-y-auto rounded-2xl bg-white p-5 shadow-xl`}>
        <div className="mb-4 flex flex-wrap items-center justify-between gap-x-3 gap-y-2">
          <div className="flex min-w-0 flex-wrap items-center gap-x-3 gap-y-2">
            <h3 className="text-lg font-semibold text-slate-900">{title}</h3>
            {titleAside}
          </div>
          <button
            type="button"
            className="-m-1 flex h-11 min-w-11 shrink-0 items-center justify-center rounded-lg text-2xl leading-none text-slate-500 hover:bg-slate-100 hover:text-slate-800"
            onClick={onClose}
            aria-label="閉じる"
          >
            ×
          </button>
        </div>
        {children}
      </div>
    </div>
  )
}

export function FormError({ message }: { message: string | null }) {
  if (!message) return null
  return (
    <div className="rounded-lg border border-rose-200 bg-rose-50 p-2 text-xs text-rose-700">{message}</div>
  )
}

export function FieldLabel({ children }: { children: ReactNode }) {
  return <span className="text-slate-600">{children}</span>
}

export function FormActions({
  onCancel,
  submitLabel = "保存",
  submitting = false,
  disabled = false,
}: {
  onCancel: () => void
  submitLabel?: string
  submitting?: boolean
  disabled?: boolean
}) {
  return (
    <div className="flex justify-end gap-2 pt-2">
      <button
        type="button"
        onClick={onCancel}
        className="rounded-lg border border-slate-300 px-3 py-2 text-sm hover:bg-slate-50"
        disabled={submitting}
      >
        キャンセル
      </button>
      <button
        type="submit"
        disabled={disabled || submitting}
        className="rounded-lg bg-indigo-600 px-3 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-60"
      >
        {submitting ? "保存中…" : submitLabel}
      </button>
    </div>
  )
}
