import type { JudgmentType, TradeType } from "./api.ts"

export type TradeAxesConfig = {
  trade_type: TradeType
  judgment_type: JudgmentType
}

export type TimelineTab = "real" | "virtual-human" | "virtual-ai"

export function tradeAxesFromTimelineTab(tab: TimelineTab): TradeAxesConfig {
  if (tab === "real") return { trade_type: "real", judgment_type: "human" }
  if (tab === "virtual-human") return { trade_type: "virtual", judgment_type: "human" }
  return { trade_type: "virtual", judgment_type: "ai" }
}

export function timelineTabLabel(tab: TimelineTab): string {
  if (tab === "real") return "実取引"
  if (tab === "virtual-human") return "仮想・人間"
  return "仮想・AI"
}

export function timelineTabDescription(tab: TimelineTab): string {
  if (tab === "real") return "証券口座など実際の売買"
  if (tab === "virtual-human") return "紙トレード・検証用（自分の判断）"
  return "AI スクリプトに沿った仮想トレード"
}
