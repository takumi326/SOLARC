# frozen_string_literal: true

class LineChangesController < ApplicationController
  include StockTimelineRedirect
  include RejectsOmittedAiTrades
  include TradeEventCrud

  before_action :set_line_change, only: [ :show, :edit, :update, :destroy ]
  before_action :load_context, only: [ :new, :create, :show, :edit, :update ]
  before_action :reject_omitted_ai_judgment!

  def new
    @line_change = TradeEvent.new(
      kind: :line_change,
      stock_id: @stock&.id,
      trade_type: @trade_type,
      judgment_type: @judgment_type,
      ai_script_id: @ai_script_id,
      changed_on: Date.current
    )
  end

  def create
    begin
      @line_change = TradeEventRegistrar.new(stock: Stock.find(line_change_params[:stock_id])).call(
        kind: :line_change,
        executed_at: executed_at_from(line_change_params[:changed_on]),
        **event_attrs_from(line_change_params)
      )
      redirect_to stock_timeline_path_for_record(@line_change), notice: "ライン設定を記録しました。"
    rescue ActiveRecord::RecordInvalid => e
      @line_change = e.record
      load_context_from_line_change(@line_change) if @line_change.stock
      load_context unless @stock
      flash.now[:alert] = @line_change.errors.full_messages.join(" ")
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
  end

  def update
    if update_trade_event!(@line_change, event_attrs_from(line_change_params), executed_at_from(line_change_params[:changed_on]))
      redirect_to stock_timeline_path_for_record(@line_change), notice: "ライン設定を保存しました。"
    else
      load_context_from_line_change(@line_change)
      flash.now[:alert] = @line_change.errors.full_messages.join(" ")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    path = stock_timeline_path_for_record(@line_change)
    destroy_trade_event!(@line_change)
    redirect_to path, notice: "ライン設定を削除しました。"
  end

  private

  def set_line_change
    @line_change = TradeEvent.line_change.includes(:stock).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to stocks_path, alert: "ライン設定が見つかりません。"
  end

  def load_context
    if @line_change&.stock
      load_context_from_line_change(@line_change)
    else
      @stock = Stock.find_by(id: params[:stock_id]) if params[:stock_id].present?
      @trade_type = params[:trade_type].presence || "real"
      @judgment_type = params[:judgment_type].presence || "human"
      @ai_script_id = parse_optional_id(params[:ai_script_id])
      @ai_scripts = AiScript.order(id: :desc) if @judgment_type == "ai"
    end
  end

  def load_context_from_line_change(record)
    @stock = record.stock
    @trade_type = record.trade_type
    @judgment_type = record.judgment_type
    @ai_script_id = record.ai_script_id
    @ai_scripts = AiScript.order(id: :desc) if @judgment_type == "ai"
  end

  def line_change_params
    params.expect(line_change: [
      :stock_id, :trade_type, :judgment_type, :ai_script_id,
      :changed_on, :stop_loss, :target_price, :reason
    ])
  end
end
