import { api, type StockTradeEventRow } from "./api.ts"
import { apiErrorMessage } from "./errors.ts"

export async function deleteTradeEvent(row: StockTradeEventRow, onDone: () => void) {
  const label = row.kind === "entry" ? "エントリー" : row.kind === "exit" ? "イグジット" : "ライン変更"
  if (!window.confirm(`${label}を削除しますか？`)) return
  try {
    if (row.kind === "entry") await api.deleteEntry(row.id)
    else if (row.kind === "exit") await api.deleteStockExit(row.id)
    else await api.deleteLineChange(row.id)
    onDone()
  } catch (e) {
    window.alert(apiErrorMessage(e))
  }
}
