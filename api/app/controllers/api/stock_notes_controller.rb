# frozen_string_literal: true

module Api
  class StockNotesController < ApplicationController
    before_action :set_stock
    before_action :set_note, only: [ :update, :destroy ]

    def index
      notes = @stock.stock_notes.order(noted_on: :desc, id: :desc)
      render json: { data: notes.map { |n| note_json(n) } }
    end

    def create
      note = @stock.stock_notes.build(note_params)
      if note.save
        render json: { data: note_json(note) }, status: :created
      else
        render_validation_error(note)
      end
    end

    def update
      if @note.update(note_params)
        render json: { data: note_json(@note) }
      else
        render_validation_error(@note)
      end
    end

    def destroy
      @note.destroy!
      head :no_content
    end

    private

    def set_stock
      @stock = Stock.find(params[:stock_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: { code: "not_found", message: "銘柄が見つかりません" } }, status: :not_found
    end

    def set_note
      return if performed?

      @note = @stock.stock_notes.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: { code: "not_found", message: "観察メモが見つかりません" } }, status: :not_found
    end

    def note_params
      params.expect(stock_note: [ :noted_on, :title, :note ])
    end

    def note_json(n)
      {
        id: n.id,
        stock_id: n.stock_id,
        noted_on: n.noted_on.iso8601,
        title: n.title,
        note: n.note,
        created_at: n.created_at.iso8601,
        updated_at: n.updated_at.iso8601
      }
    end

    def render_validation_error(record)
      render json: { error: { code: "validation_error", message: "保存できませんでした。", details: record.errors } },
             status: :unprocessable_entity
    end
  end
end
