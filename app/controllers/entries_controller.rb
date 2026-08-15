# frozen_string_literal: true

class EntriesController < ApplicationController
  include StockTimelineRedirect
  include RejectsOmittedAiTrades
  include TradeEventCrud

  before_action :set_entry, only: [ :show, :edit, :update, :destroy ]
  before_action :load_context, only: [ :new, :create, :show, :edit, :update ]
  before_action :reject_omitted_ai_judgment!

  def new
    @entry = TradeEvent.new(
      kind: :entry,
      stock_id: @stock&.id,
      trade_type: @trade_type,
      judgment_type: @judgment_type,
      ai_script_id: @ai_script_id
    )
  end

  def create
    begin
      @entry = TradeEventRegistrar.new(stock: Stock.find(entry_params[:stock_id])).call(
        kind: :entry,
        executed_at: entry_params[:traded_at].presence && executed_at_from(entry_params[:traded_at]),
        **event_attrs_from(entry_params).merge(initial_line_attrs)
      )
      redirect_to stock_timeline_path_for_record(@entry), notice: "エントリーを記録しました。"
    rescue ActiveRecord::RecordInvalid => e
      @entry = e.record
      @entry.kind = :entry if @entry.respond_to?(:kind=)
      load_context_from_entry(@entry)
      flash.now[:alert] = @entry.errors.full_messages.join(" ")
      render :new, status: :unprocessable_entity
    rescue ActiveRecord::RecordNotFound
      @entry = TradeEvent.new(event_attrs_from(entry_params).merge(kind: :entry))
      @entry.errors.add(:stock_id, "が見つかりません")
      load_context
      flash.now[:alert] = @entry.errors.full_messages.join(" ")
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
  end

  def update
    if update_trade_event!(@entry, event_attrs_from(entry_params), executed_at_from(entry_params[:traded_at]))
      redirect_to stock_timeline_path_for_record(@entry), notice: "エントリーを保存しました。"
    else
      load_context_from_entry(@entry)
      flash.now[:alert] = @entry.errors.full_messages.join(" ")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    path = stock_timeline_path_for_record(@entry)
    destroy_trade_event!(@entry)
    redirect_to path, notice: "エントリーを削除しました。"
  end

  private

  def set_entry
    @entry = TradeEvent.entry.includes(:stock).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to stocks_path, alert: "エントリーが見つかりません。"
  end

  def load_context
    if @entry&.stock
      load_context_from_entry(@entry)
    else
      @stock = Stock.find_by(id: params[:stock_id]) if params[:stock_id].present?
      @trade_type = params[:trade_type].presence || "real"
      @judgment_type = params[:judgment_type].presence || "human"
      @ai_script_id = parse_optional_id(params[:ai_script_id])
      @ai_scripts = AiScript.order(id: :desc) if @judgment_type == "ai"
    end
  end

  def load_context_from_entry(entry)
    @stock = entry.stock
    @trade_type = entry.trade_type
    @judgment_type = entry.judgment_type
    @ai_script_id = entry.ai_script_id
    @ai_scripts = AiScript.order(id: :desc) if @judgment_type == "ai"
  end

  def entry_params
    params.expect(entry: [
      :stock_id, :trade_type, :judgment_type, :ai_script_id,
      :expected_price, :actual_price, :shares, :traded_at,
      :entry_reason, :scenario, :memo
    ])
  end

  def initial_line_attrs
    ep = params[:entry]
    return {} unless ep.is_a?(ActionController::Parameters)

    il = ep[:initial_line]
    return {} if il.blank?

    il =
      if il.is_a?(ActionController::Parameters)
        il.permit(:stop_loss, :target_price, :reason)
      else
        ActionController::Parameters.new(il).permit(:stop_loss, :target_price, :reason)
      end
    {
      initial_stop: il[:stop_loss].presence,
      initial_target: il[:target_price].presence
    }.compact
  end
end
