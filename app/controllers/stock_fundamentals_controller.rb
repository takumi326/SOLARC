# frozen_string_literal: true

class StockFundamentalsController < ApplicationController
  def show
    load_prompt_and_stocks
  end

  def update
    preference = UserPreference.find_or_initialize_by(owner_key: preference_owner_key)
    raw = params.dig(:stock_fundamentals, :prompt).to_s
    normalized = raw.strip
    preference.stock_fundamentals_prompt = if normalized.blank? || normalized == StockFundamentalsPrompt::DEFAULT
      nil
    else
      raw
    end

    if preference.save
      redirect_to stock_fundamentals_path(period_query_params), notice: "プロンプトを保存しました。"
    else
      load_prompt_and_stocks
      @prompt = raw
      flash.now[:alert] = preference.errors.full_messages.join(" ")
      render :show, status: :unprocessable_entity
    end
  end

  private

  def load_prompt_and_stocks
    @watch_starts_on = parse_optional_date(params[:starts_on])
    @watch_ends_on = parse_optional_date(params[:ends_on])
    query = StockIndexQuery.new
    result = if @watch_starts_on.present? && @watch_ends_on.present?
      query.watch_period_stocks(@watch_starts_on, @watch_ends_on)
    else
      query.current_watch_stocks
    end
    @stocks = result.stocks
    @stock_flags = result.stock_flags
    @watch_period_label = watch_period_label
    preference = UserPreference.find_or_initialize_by(owner_key: preference_owner_key)
    @prompt_body = StockFundamentalsPrompt.draft_for(preference)
    @stock_list_text = watch_stocks_list_text
    @prompt = @prompt_body
  end

  def watch_stocks_list_text
    return "（なし）" if @stocks.empty?

    @stocks.map { |stock| "#{stock.code} #{stock.name}" }.join("\n")
  end

  def parse_optional_date(value)
    return nil if value.blank?

    Date.iso8601(value.to_s)
  rescue ArgumentError, Date::Error
    nil
  end

  def watch_period_label
    return nil if @watch_starts_on.blank? || @watch_ends_on.blank?

    if @watch_starts_on == @watch_ends_on
      @watch_starts_on.strftime("%-m/%-d")
    else
      "#{@watch_starts_on.strftime("%-m/%-d")}〜#{@watch_ends_on.strftime("%-m/%-d")}"
    end
  end

  def period_query_params
    {
      starts_on: @watch_starts_on&.iso8601 || params[:starts_on].presence,
      ends_on: @watch_ends_on&.iso8601 || params[:ends_on].presence
    }.compact
  end
end
