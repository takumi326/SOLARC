# frozen_string_literal: true

class StockExitsController < ApplicationController
  include StockTimelineRedirect
  include RejectsOmittedAiTrades
  include TradeEventCrud

  before_action :set_exit, only: [ :show, :edit, :update, :destroy ]
  before_action :load_context, only: [ :new, :create, :show, :edit, :update ]
  before_action :reject_omitted_ai_judgment!

  def new
    @exit = TradeEvent.new(
      kind: :exit,
      stock_id: @stock&.id,
      trade_type: @trade_type,
      judgment_type: @judgment_type,
      ai_script_id: @ai_script_id
    )
  end

  def create
    begin
      @exit = TradeEventRegistrar.new(stock: Stock.find(exit_params[:stock_id])).call(
        kind: :exit,
        executed_at: exit_params[:traded_at].presence && executed_at_from(exit_params[:traded_at]),
        **event_attrs_from(exit_params)
      )
      redirect_to stock_timeline_path_for_record(@exit), notice: "イグジットを記録しました。"
    rescue ActiveRecord::RecordInvalid => e
      @exit = e.record
      load_context_from_exit(@exit) if @exit.stock
      load_context unless @stock
      flash.now[:alert] = @exit.errors.full_messages.join(" ")
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
  end

  def update
    if update_trade_event!(@exit, event_attrs_from(exit_params), executed_at_from(exit_params[:traded_at]))
      redirect_to stock_timeline_path_for_record(@exit), notice: "イグジットを保存しました。"
    else
      load_context_from_exit(@exit)
      flash.now[:alert] = @exit.errors.full_messages.join(" ")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    path = stock_timeline_path_for_record(@exit)
    destroy_trade_event!(@exit)
    redirect_to path, notice: "イグジットを削除しました。"
  end

  private

  def set_exit
    @exit = TradeEvent.exit.includes(:stock).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to stocks_path, alert: "イグジットが見つかりません。"
  end

  def load_context
    if @exit&.stock
      load_context_from_exit(@exit)
    else
      @stock = Stock.find_by(id: params[:stock_id]) if params[:stock_id].present?
      @trade_type = params[:trade_type].presence || "real"
      @judgment_type = params[:judgment_type].presence || "human"
      @ai_script_id = parse_optional_id(params[:ai_script_id])
      @ai_scripts = AiScript.order(id: :desc) if @judgment_type == "ai"
    end
  end

  def load_context_from_exit(record)
    @stock = record.stock
    @trade_type = record.trade_type
    @judgment_type = record.judgment_type
    @ai_script_id = record.ai_script_id
    @ai_scripts = AiScript.order(id: :desc) if @judgment_type == "ai"
  end

  def exit_params
    params.expect(exit: [
      :stock_id, :trade_type, :judgment_type, :ai_script_id,
      :expected_price, :actual_price, :shares, :traded_at,
      :exit_reason, :review_result, :review_missed, :review_learning, :memo
    ])
  end
end
