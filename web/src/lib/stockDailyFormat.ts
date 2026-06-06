/** `YYYY-MM-DD` → `YYYY年MM月DD日` */
export function formatRecordDateJp(isoDate: string): string {
  const parts = isoDate.split("-")
  if (parts.length !== 3) return isoDate
  const [y, mo, da] = parts
  const yn = Number(y)
  const mon = Number(mo)
  const dayn = Number(da)
  if (!Number.isFinite(yn) || !Number.isFinite(mon) || !Number.isFinite(dayn)) return isoDate
  return `${yn}年${String(mon).padStart(2, "0")}月${String(dayn).padStart(2, "0")}日`
}
