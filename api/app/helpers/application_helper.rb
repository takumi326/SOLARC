module ApplicationHelper
  def format_yen(amount)
    n = amount.to_d
    n = 0 unless n.finite?
    "¥#{n.round.to_fs(:delimited)}"
  end

  def format_yen_delta(amount)
    n = amount.to_d
    return format_yen(0) unless n.finite?

    prefix = n.positive? ? "+" : ""
    "#{prefix}#{format_yen(n)}"
  end

  def format_month_label(date)
    d = date.is_a?(Date) ? date : Date.parse(date.to_s)
    "#{d.year}/#{format('%02d', d.month)}"
  rescue Date::Error
    date.to_s
  end

  def format_month_input(date)
    d = date.is_a?(Date) ? date : Date.parse(date.to_s)
    d.strftime("%Y-%m")
  rescue Date::Error
    ""
  end

  def add_months_to_input(month_input, delta)
    y, m = month_input.split("-").map(&:to_i)
    date = Date.new(y, m, 1).advance(months: delta)
    format_month_input(date)
  rescue StandardError
    month_input
  end

  def btn_classes(variant = :primary, extra: nil)
    base = "inline-flex items-center justify-center rounded-lg px-3 py-1.5 text-sm font-medium"
    classes = case variant.to_sym
    when :primary then "#{base} bg-indigo-600 text-white hover:bg-indigo-500"
    when :secondary then "#{base} border border-slate-300 bg-white text-slate-800 hover:bg-slate-50"
    when :danger then "#{base} border border-rose-300 text-rose-700 hover:bg-rose-50"
    when :link then "#{base} border border-indigo-300 text-indigo-700 hover:bg-indigo-50"
    else "#{base} border border-slate-300 text-slate-700 hover:bg-slate-50"
    end
    extra.present? ? "#{classes} #{extra}" : classes
  end

  def finance_mode_badge(mode, path: nil, label: nil)
    pill = mode == "実" ? "rounded-full bg-slate-200 px-2 py-0.5 text-xs text-slate-700" : "rounded-full bg-indigo-100 px-2 py-0.5 text-xs text-indigo-700"
    if path
      link_to mode, path, class: pill, aria: { label: label }
    else
      tag.span(mode, class: pill)
    end
  end

  def breakdown_tab_class(active)
    base = "rounded-full px-3 py-1 transition-colors"
    active ? "#{base} bg-white text-slate-800 shadow-sm" : "#{base} text-slate-500 hover:text-slate-700"
  end

  def recurring_type_label(type)
    { "one_time" => "単発", "recurring" => "定期" }[type.to_s] || type
  end

  def recurring_cycle_label(cycle)
    { "monthly" => "月次", "yearly" => "年次" }[cycle.to_s] || cycle
  end

  def payment_method_type_label(type)
    {
      "card" => "クレジットカード",
      "bank_debit" => "口座引き落とし",
      "bank_withdrawal" => "口座引き出し"
    }[type.to_s] || type
  end

  def nav_link(label, path, also_active: nil, **options)
    paths = [ path, *Array(also_active) ]
    active = paths.any? { |p| current_page?(p) }
    base = "block rounded-lg px-3 py-2 text-sm"
    classes = active ? "#{base} bg-indigo-600 text-white" : "#{base} text-slate-600 hover:bg-slate-100"
    link_to label, path, class: classes, **options
  end

  def stock_field_value(note, field)
    case field
    when "hypothesis" then note.hypothesis
    when "result" then note.result
    when "sector" then note.sector_research
    else ""
    end
  end

  def trade_event_kind_label(kind)
    case kind.to_s
    when "entry" then "エントリー（買い）"
    when "exit" then "イグジット（売り）"
    when "line_change" then "ライン変更"
    else kind.to_s
    end
  end

  def trade_event_summary(row)
    record = row.record
    case row.kind.to_s
    when "entry" then record.entry_reason.to_s.truncate(80)
    when "exit" then record.exit_reason.to_s.truncate(80)
    when "line_change" then record.reason.to_s.truncate(80)
    else ""
    end
  end

  def timeline_tab_label(trade_type, judgment_type)
    if trade_type == "real"
      "実取引"
    elsif judgment_type == "human"
      "仮想・人間"
    else
      "仮想・AI"
    end
  end

  def timeline_tabs
    [
      { trade_type: "real", judgment_type: "human", label: "実取引" },
      { trade_type: "virtual", judgment_type: "human", label: "仮想・人間" },
      { trade_type: "virtual", judgment_type: "ai", label: "仮想・AI" }
    ]
  end

  def stock_trade_event_path_for(row)
    case row.kind.to_s
    when "entry" then entry_path(row.id)
    when "exit" then exit_path(row.id)
    when "line_change" then line_change_path(row.id)
    end
  end

  def stock_trade_edit_path_for(row)
    case row.kind.to_s
    when "entry" then edit_entry_path(row.id)
    when "exit" then edit_exit_path(row.id)
    when "line_change" then edit_line_change_path(row.id)
    end
  end

  def stock_trade_destroy_path_for(row)
    case row.kind.to_s
    when "entry" then entry_path(row.id)
    when "exit" then exit_path(row.id)
    when "line_change" then line_change_path(row.id)
    end
  end

  def format_decimal(value)
    return "" if value.blank?

    value.to_s("F")
  end

  def format_date_value(value)
    return "" if value.blank?

    value.respond_to?(:to_date) ? value.to_date.iso8601 : value.to_s
  end

  def btn_primary_classes
    "rounded-lg bg-indigo-600 px-3 py-2 text-sm font-medium text-white hover:bg-indigo-500 cursor-pointer"
  end

  def btn_secondary_classes
    "rounded-lg border border-slate-300 px-3 py-2 text-sm hover:bg-slate-50"
  end

  def stock_timeline_path_for(stock, trade_type:, judgment_type:, ai_script_id: nil)
    stock_path(stock, trade_type: trade_type, judgment_type: judgment_type, ai_script_id: ai_script_id)
  end

  def stock_timeline_path_for_record(record)
    stock_timeline_path_for(
      record.stock,
      trade_type: record.trade_type,
      judgment_type: record.judgment_type,
      ai_script_id: record.ai_script_id
    )
  end
end
