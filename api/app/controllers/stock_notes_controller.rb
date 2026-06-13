# frozen_string_literal: true

class StockNotesController < ApplicationController
  before_action :set_stock
  before_action :set_note, only: [ :edit, :update, :destroy ]

  def new
    @note = @stock.stock_notes.build(noted_on: Date.current)
  end

  def create
    @note = @stock.stock_notes.build(note_params)
    if @note.save
      redirect_to stock_path(@stock), notice: "観察メモを追加しました。"
    else
      flash.now[:alert] = @note.errors.full_messages.join(" ")
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @note.update(note_params)
      redirect_to stock_path(@stock), notice: "観察メモを保存しました。"
    else
      flash.now[:alert] = @note.errors.full_messages.join(" ")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @note.destroy!
    redirect_to stock_path(@stock), notice: "観察メモを削除しました。"
  end

  private

  def set_stock
    @stock = Stock.find(params[:stock_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to stocks_path, alert: "銘柄が見つかりません。"
  end

  def set_note
    @note = @stock.stock_notes.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to stock_path(@stock), alert: "観察メモが見つかりません。"
  end

  def note_params
    params.expect(stock_note: [ :noted_on, :title, :note ])
  end
end
