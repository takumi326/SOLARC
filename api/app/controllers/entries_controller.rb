# frozen_string_literal: true

class EntriesController < ApplicationController
  include StockTimelineRedirect

  before_action :set_entry, only: [ :show, :edit, :update, :destroy ]
  before_action :load_context, only: [ :new, :create, :show, :edit, :update ]

  def new
    @entry = Entry.new(
      stock_id: @stock&.id,
      trade_type: @trade_type,
      judgment_type: @judgment_type,
      ai_script_id: @ai_script_id
    )
  end

  def create
    line = initial_line_hash
    @entry = Entry.new(entry_params)
    begin
      ActiveRecord::Base.transaction do
        @entry.save!
        create_initial_line_change!(@entry, line) if line.present?
      end
      redirect_to stock_timeline_path_for_record(@entry), notice: "エントリーを記録しました。"
    rescue ActiveRecord::RecordInvalid
      load_context_from_entry(@entry)
      flash.now[:alert] = @entry.errors.full_messages.join(" ")
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
  end

  def update
    if @entry.update(entry_params)
      redirect_to stock_timeline_path_for_record(@entry), notice: "エントリーを保存しました。"
    else
      load_context_from_entry(@entry)
      flash.now[:alert] = @entry.errors.full_messages.join(" ")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    stock = @entry.stock
    path = stock_timeline_path_for_record(@entry)
    @entry.destroy!
    redirect_to path, notice: "エントリーを削除しました。"
  end

  private

  def set_entry
    @entry = Entry.includes(:stock).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to stocks_path, alert: "エントリーが見つかりません。"
  end

  def load_context
    if @entry
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

  def initial_line_hash
    ep = params[:entry]
    return nil unless ep.is_a?(ActionController::Parameters)

    il = ep[:initial_line]
    return nil if il.blank?

    il =
      if il.is_a?(ActionController::Parameters)
        il.permit(:stop_loss, :target_price, :reason)
      else
        ActionController::Parameters.new(il).permit(:stop_loss, :target_price, :reason)
      end
    return nil if il[:stop_loss].blank? && il[:target_price].blank?

    { stop_loss: il[:stop_loss].presence, target_price: il[:target_price].presence, reason: il[:reason].presence }
  end

  def create_initial_line_change!(entry, line)
    LineChange.create!(
      stock_id: entry.stock_id,
      trade_type: entry.trade_type,
      judgment_type: entry.judgment_type,
      ai_script_id: entry.ai_script_id,
      changed_on: entry.traded_at || Time.zone.today,
      stop_loss: line[:stop_loss],
      target_price: line[:target_price],
      reason: line[:reason]
    )
  end

  def parse_optional_id(v)
    return nil if v.blank?

    Integer(v)
  rescue ArgumentError, TypeError
    nil
  end
end
