export const rowActionButtonBaseClass =
  "inline-flex min-h-9 min-w-[3.25rem] items-center justify-center rounded-md border px-3 py-1.5 text-sm font-medium whitespace-nowrap transition-colors"

type Props = {
  onDetail?: () => void
  onEdit?: () => void
  onDelete?: () => void
  className?: string
}

export function RowActionButtons({ onDetail, onEdit, onDelete, className }: Props) {
  if (!onDetail && !onEdit && !onDelete) return null

  return (
    <div className={`flex items-center gap-2 whitespace-nowrap ${className ?? ""}`}>
      {onDetail && (
        <button
          type="button"
          className={`${rowActionButtonBaseClass} border-indigo-300 text-indigo-700 hover:bg-indigo-50`}
          onClick={onDetail}
        >
          詳細
        </button>
      )}
      {onEdit && (
        <button
          type="button"
          className={`${rowActionButtonBaseClass} border-slate-300 text-slate-700 hover:bg-slate-50`}
          onClick={onEdit}
        >
          編集
        </button>
      )}
      {onDelete && (
        <button
          type="button"
          className={`${rowActionButtonBaseClass} border-rose-300 text-rose-700 hover:bg-rose-50`}
          onClick={onDelete}
        >
          削除
        </button>
      )}
    </div>
  )
}
