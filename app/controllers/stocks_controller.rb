# frozen_string_literal: true

class StocksController < ApplicationController
  include RejectsOmittedAiTrades

  before_action :set_stock, only: [ :show, :edit, :update, :timeline ]
  before_action :assign_timeline_tab_params, only: [ :edit, :update ]
  before_action :reject_omitted_ai_timeline!, only: [ :show, :timeline, :edit, :update ]

  def index
    result = StockIndexQuery.call
    @stocks = result.stocks
    @stock_flags = result.stock_flags
  end

  def lookup
    q = params[:q].to_s.strip
    stocks = q.blank? ? Stock.none : Stock.search_by_term(q).includes(:industry).ordered.limit(20)
    render json: stocks.map { |stock|
      { code: stock.code, name: stock.name, url: stock_path(stock) }
    }
  end

  def show
    @watch_items = @stock.stock_watch_items.includes(:stock_watch_batch).joins(:stock_watch_batch)
                         .order("stock_watch_batches.starts_on DESC, stock_watch_batches.id DESC")
    load_timeline_context!
  end

  def timeline
    redirect_to stock_path(@stock, **timeline_query_params)
  end

  def edit
    @industries = Industry.order(:name)
  end

  def update
    if @stock.update(stock_params)
      redirect_to stock_path(@stock, **timeline_query_params), notice: "銘柄設定を保存しました。"
    else
      @industries = Industry.order(:name)
      flash.now[:alert] = @stock.errors.full_messages.join(" ")
      render :edit, status: :unprocessable_entity
    end
  end

  def import_new
  end

  def import
    file = params[:file]
    unless file.respond_to?(:read)
      redirect_to new_import_stocks_path, alert: "CSV ファイルを選択してください。"
      return
    end

    result = StockCsvImporter.import!(file)
    redirect_to stocks_path,
                notice: "読み込んで登録しました。新規業種 #{result.created_industries} / 新規銘柄 #{result.created_stocks} / 更新 #{result.updated_stocks} / スキップ #{result.skipped_rows}。"
  rescue StandardError => e
    Rails.logger.error("[StockCsvImporter] #{e.class}: #{e.message}")
    redirect_to new_import_stocks_path, alert: "CSV の取り込みに失敗しました。UTF-8 または Shift_JIS で、列「銘柄名・コード・業種」を含む形式か確認してください。"
  end

  private

  def set_stock
    @stock = Stock.includes(:industry).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to stocks_path, alert: "銘柄が見つかりません。"
  end

  def stock_params
    params.expect(stock: [ :memo, :industry_id ])
  end

  def parse_optional_id(v)
    return nil if v.blank?

    Integer(v)
  rescue ArgumentError, TypeError
    nil
  end

  def timeline_query_params
    {
      trade_type: params[:trade_type].presence || "real",
      judgment_type: params[:judgment_type].presence || "human",
      ai_script_id: params[:ai_script_id].presence
    }.compact
  end

  def assign_timeline_tab_params
    @trade_type = timeline_query_params[:trade_type]
    @judgment_type = timeline_query_params[:judgment_type]
    @ai_script_id = timeline_query_params[:ai_script_id]
  end

  def load_timeline_context!
    assign_timeline_tab_params
    @ai_scripts = AiScript.order(id: :desc) if @judgment_type == "ai" && AiTradeFeatures.enabled?

    result = StockTimelineBuilder.build(
      stock: @stock,
      trade_type: @trade_type,
      judgment_type: @judgment_type,
      ai_script_id: parse_optional_id(@ai_script_id)
    )
    @timeline_rows = result[:rows]
    @timeline_groups = result[:groups]
    @current_line = result[:current_line]
    @current_position = result[:position]
  end

  def reject_omitted_ai_timeline!
    return unless AiTradeFeatures.omitted?
    return unless params[:judgment_type].to_s == "ai"

    reject_omitted_ai_trades!
  end
end
