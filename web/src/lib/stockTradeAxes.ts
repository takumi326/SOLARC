import type { TradeType } from "./api.ts"

export type TradeAxesConfig = {
  trade_type: TradeType
  judgment_type: "human"
}

export type TimelineTab = "real" | "virtual-human"

export function tradeAxesFromTimelineTab(tab: TimelineTab): TradeAxesConfig {
  if (tab === "real") return { trade_type: "real", judgment_type: "human" }
  return { trade_type: "virtual", judgment_type: "human" }
}

export function timelineTabLabel(tab: TimelineTab): string {
  if (tab === "real") return "実取引"
  return "仮想"
}

export function timelineTabDescription(tab: TimelineTab): string {
  if (tab === "real") return "証券口座など実際の売買"
  return "紙トレード・検証用"
}
