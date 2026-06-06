# frozen_string_literal: true

module Api
  class LineChangesController < ApplicationController
    before_action :set_line_change, only: [ :show, :update, :destroy ]

    def show
      render json: { data: line_change_json(@line_change) }
    end

    def create
      lc = LineChange.new(line_change_params)
      if lc.save
        render json: { data: line_change_json(lc) }, status: :created
      else
        render_validation_error(lc)
      end
    end

    def update
      if @line_change.update(line_change_params)
        render json: { data: line_change_json(@line_change) }
      else
        render_validation_error(@line_change)
      end
    end

    def destroy
      @line_change.destroy!
      head :no_content
    end

    private

    def set_line_change
      @line_change = LineChange.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: { code: "not_found", message: "ライン変更が見つかりません" } }, status: :not_found
    end

    def line_change_params
      params.expect(line_change: [
        :stock_id, :trade_type, :judgment_type, :ai_script_id,
        :changed_on, :stop_loss, :target_price, :reason
      ])
    end

    def line_change_json(l)
      {
        id: l.id,
        stock_id: l.stock_id,
        trade_type: l.trade_type,
        judgment_type: l.judgment_type,
        ai_script_id: l.ai_script_id,
        changed_on: l.changed_on.iso8601,
        stop_loss: l.stop_loss&.to_s("F"),
        target_price: l.target_price&.to_s("F"),
        reason: l.reason,
        created_at: l.created_at.iso8601,
        updated_at: l.updated_at.iso8601
      }
    end

    def render_validation_error(record)
      render json: { error: { code: "validation_error", message: "保存できませんでした。", details: record.errors } },
             status: :unprocessable_entity
    end
  end
end
