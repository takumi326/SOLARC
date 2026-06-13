# frozen_string_literal: true

require "kramdown"

module StockDailyNotesHelper
  STOCK_DAILY_EXTERNAL_LINKS = {
    claude: { label: "Claude", href: "https://claude.ai/new" },
    world_market: { label: "世界の市況", href: "https://nikkei225jp.com/" },
    today_market: { label: "本日の市況", href: "https://www.sc.mufg.jp/market/today_market/index.html" },
    japan_market: { label: "日本の市況", href: "https://nikkei225jp.com/chart/" }
  }.freeze

  STOCK_DAILY_WORKFLOW_GROUPS = [
    { field: "hypothesis", links: %i[claude world_market] },
    { field: "result", links: %i[claude today_market japan_market] },
    { field: "sector", links: %i[claude japan_market] }
  ].freeze

  MARKDOWN_DETAIL_CLASS =
    "min-h-0 min-w-0 text-sm text-slate-800 [&>*:first-child]:mt-0 " \
    "[&_h1]:mb-2 [&_h1]:mt-3 [&_h1]:text-base [&_h1]:font-bold " \
    "[&_h2]:mb-1.5 [&_h2]:mt-2.5 [&_h2]:text-sm [&_h2]:font-semibold " \
    "[&_p]:my-1.5 [&_p]:leading-relaxed [&_ul]:my-1.5 [&_ul]:list-disc [&_ul]:pl-5 " \
    "[&_pre]:my-2 [&_pre]:overflow-auto [&_pre]:rounded-lg [&_pre]:bg-slate-100 [&_pre]:p-2 [&_pre]:font-mono [&_pre]:text-xs"

  def stock_daily_action_button_class
    "inline-flex h-9 shrink-0 items-center justify-center rounded-lg border border-slate-300 bg-white px-2 text-xs font-medium text-slate-800 hover:bg-slate-50 sm:h-auto sm:px-3 sm:py-1.5 sm:text-sm"
  end

  def stock_daily_external_link_class
    "inline-flex h-9 shrink-0 items-center justify-center rounded-lg border border-indigo-200 bg-white px-2 text-xs font-medium text-indigo-700 hover:bg-indigo-50 sm:h-auto sm:px-3 sm:py-1.5 sm:text-sm"
  end

  def copy_stock_daily_prompt_button(field:, notes:, prompts:)
    date = Date.current.iso8601
    text = StockDailyPromptBuilder.copy_text(field: field, date: date, notes: notes, prompts: prompts)
    tag.button(
      "プロンプトコピー",
      type: "button",
      class: stock_daily_action_button_class,
      data: { copy_text: text, copy_label: "プロンプトコピー", copy_flash: "プロンプトをコピーしました" }
    )
  end

  def stock_daily_field_filled?(text)
    text.to_s.strip.present?
  end

  def render_stock_daily_markdown(body)
    text = body.to_s
    if text.strip.blank?
      return tag.p("（未入力）", class: "text-xs text-slate-400")
    end

    html = ::Kramdown::Document.new(text).to_html
    tag.div(html.html_safe, class: MARKDOWN_DETAIL_CLASS)
  end
end
