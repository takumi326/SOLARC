# frozen_string_literal: true

class StockDailyPromptBuilder
  FIELD_LABELS = {
    "hypothesis" => "仮説",
    "result" => "結果",
    "sector" => "セクター調べ"
  }.freeze

  COPY_LABELS = {
    "hypothesis" => "仮説プロンプトコピー",
    "result" => "結果プロンプトコピー",
    "sector" => "セクター調べプロンプトコピー"
  }.freeze

  class << self
    def prompts_from_preference(preference)
      attrs = preference.attributes
      {
        hypothesis: hypothesis_prompt_value(attrs).to_s.rstrip,
        result: attrs["stock_daily_result_prompt"].to_s.rstrip,
        sector: attrs["stock_daily_sector_prompt"].to_s.rstrip
      }
    end

    def copy_text(field:, date:, notes:, prompts:)
      raw = prompts[field.to_sym]
      hypothesis_body = hypothesis_body_for(field:, date:, notes:)
      result_body = result_body_for(field:, date:, notes:)
      apply_placeholders(raw, date, hypothesis_body, result_body)
    end

    def format_record_date_jp(iso_date)
      parts = iso_date.to_s.split("-")
      return iso_date.to_s if parts.length != 3

      y, mo, da = parts
      "#{y}年#{mo}月#{da}日"
    end

    private

    def hypothesis_prompt_value(attrs)
      if attrs.key?("stock_daily_hypothesis_prompt")
        attrs["stock_daily_hypothesis_prompt"]
      else
        attrs["stock_daily_hypothesis_template"]
      end
    end

    def uses_prev_day_fallback?(field)
      field.to_s.in?(%w[result sector])
    end

    def hypothesis_body_for(field:, date:, notes:)
      rows = notes.map { |n| { date: n.recorded_on.iso8601, hypothesis: n.hypothesis } }
      if uses_prev_day_fallback?(field)
        field_with_prev_day_fallback(rows, date, :hypothesis)
      else
        note = notes.find { |n| n.recorded_on.iso8601 == date }
        note&.hypothesis.to_s
      end
    end

    def result_body_for(field:, date:, notes:)
      rows = notes.map { |n| { date: n.recorded_on.iso8601, result: n.result } }
      if uses_prev_day_fallback?(field)
        field_with_prev_day_fallback(rows, date, :result)
      else
        rows.find { |r| r[:date] == date }&.dig(:result).to_s
      end
    end

    def field_with_prev_day_fallback(rows, focus_date, key)
      map = rows.index_by { |r| normalize_date_key(r[:date]) }
      primary = map[normalize_date_key(focus_date)]&.dig(key).to_s
      return primary if primary.strip.present?

      prev = previous_calendar_day(focus_date)
      map[normalize_date_key(prev)]&.dig(key).to_s
    end

    def normalize_date_key(value)
      value.to_s.strip.slice(0, 10)
    end

    def previous_calendar_day(iso_date)
      Date.iso8601(iso_date) - 1
    rescue ArgumentError
      iso_date
    end

    def apply_placeholders(text, recorded_on_iso, hypothesis_body, result_body = "")
      jp = format_record_date_jp(recorded_on_iso)
      text.to_s
          .gsub(/\{\{\s*date_iso\s*\}\}/i, recorded_on_iso.to_s)
          .gsub(/\{\{\s*date\s*\}\}/i, jp)
          .gsub(/\{\{記録日\}\}/, jp)
          .gsub(/\{\{\s*hypothesis\s*\}\}/i, hypothesis_body.to_s)
          .gsub(/\{\{\s*result\s*\}\}/i, result_body.to_s)
    end
  end
end
