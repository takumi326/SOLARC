# frozen_string_literal: true

class LineChangesController < ApplicationController
  include StockTimelineRedirect
  include RejectsOmittedAiTrades

  before_action :set_line_change, only: [ :show, :edit, :update, :destroy ]
  before_action :load_context, only: [ :new, :create, :show, :edit, :update ]
  before_action :reject_omitted_ai_judgment!

  def new
    @line_change = LineChange.new(
      stock_id: @stock&.id,
      trade_type: @trade_type,
      judgment_type: @judgment_type,
      ai_script_id: @ai_script_id,
      changed_on: Date.current
    )
  end

  def create
    @line_change = LineChange.new(line_change_params)
    if @line_change.save
      redirect_to stock_timeline_path_for_record(@line_change), notice: "ライン変更を記録しました。"
    else
      load_context_from_line_change(@line_change)
      flash.now[:alert] = @line_change.errors.full_messages.join(" ")
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
  end

  def update
    if @line_change.update(line_change_params)
      redirect_to stock_timeline_path_for_record(@line_change), notice: "ライン変更を保存しました。"
    else
      load_context_from_line_change(@line_change)
      flash.now[:alert] = @line_change.errors.full_messages.join(" ")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    path = stock_timeline_path_for_record(@line_change)
    @line_change.destroy!
    redirect_to path, notice: "ライン変更を削除しました。"
  end

  private

  def set_line_change
    @line_change = LineChange.includes(:stock).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to stocks_path, alert: "ライン変更が見つかりません。"
  end

  def load_context
    if @line_change
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

  def parse_optional_id(v)
    return nil if v.blank?

    Integer(v)
  rescue ArgumentError, TypeError
    nil
  end
end
