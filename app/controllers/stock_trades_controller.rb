# frozen_string_literal: true

class StockTradesController < ApplicationController
  include RejectsOmittedAiTrades

  MODE_CONFIG = {
    "real" => { title: "実取引一覧", trade_type: "real", judgment_type: "human", script_filter: false },
    "virtual-human" => { title: "仮想取引一覧", trade_type: "virtual", judgment_type: "human", script_filter: false },
    "virtual-ai" => { title: "仮想取引一覧（AI）", trade_type: "virtual", judgment_type: "ai", script_filter: true }
  }.freeze

  def index
    @mode = params[:mode].to_s
    if @mode == "virtual-ai" && AiTradeFeatures.omitted?
      reject_omitted_ai_trades!
      return
    end
    @config = MODE_CONFIG[@mode]
    unless @config
      redirect_to stock_trades_path(mode: "real"), alert: "不正なモードです。"
      return
    end

    @event_kind = (params[:event_kind].presence || "all").to_s
    @settled_yes, @settled_no = settled_checkbox_values
    @settled = settled_query_value
    @from = params[:from].to_s
    @to = params[:to].to_s
    @q = params[:q].to_s.strip
    @ai_script_id = params[:ai_script_id].presence
    @ai_scripts = AiScript.order(id: :desc) if @config[:script_filter]

    query_params = {
      trade_type: @config[:trade_type],
      judgment_type: @config[:judgment_type],
      event_kind: @event_kind,
      settled: @settled,
      from: @from.presence,
      to: @to.presence,
      q: @q.presence,
      ai_script_id: @ai_script_id
    }
    @result = StockTradeEventsQuery.call(query_params)
  rescue ArgumentError => e
    redirect_to stock_trades_path(mode: @mode), alert: e.message
  end

  private

  def settled_checkbox_values
    if params.key?(:settled_yes) || params.key?(:settled_no)
      return [ params[:settled_yes] == "1", params[:settled_no] == "1" ]
    end

    case params[:settled].to_s
    when "yes" then [ true, false ]
    when "no" then [ false, true ]
    else [ true, true ]
    end
  end

  def settled_query_value
    if @settled_yes && @settled_no
      "all"
    elsif @settled_yes
      "yes"
    elsif @settled_no
      "no"
    else
      "none"
    end
  end
end
