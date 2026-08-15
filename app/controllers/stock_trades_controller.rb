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

    @from = params[:from].to_s
    @to = params[:to].to_s
    @ai_script_id = params[:ai_script_id].presence
    @ai_scripts = AiScript.order(id: :desc) if @config[:script_filter]

    query_params = {
      trade_type: @config[:trade_type],
      judgment_type: @config[:judgment_type],
      event_kind: "all",
      settled: "all",
      from: @from.presence,
      to: @to.presence,
      ai_script_id: @ai_script_id
    }
    @result = StockTradeEventsQuery.call(query_params)
  rescue ArgumentError => e
    redirect_to stock_trades_path(mode: @mode), alert: e.message
  end
end
