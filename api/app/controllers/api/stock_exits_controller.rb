# frozen_string_literal: true

module Api
  class StockExitsController < ApplicationController
    before_action :set_exit, only: [ :show, :update, :destroy ]

    def show
      render json: { data: exit_json(@exit) }
    end

    def create
      x = StockExit.new(exit_params)
      if x.save
        render json: { data: exit_json(x) }, status: :created
      else
        render_validation_error(x)
      end
    end

    def update
      if @exit.update(exit_params)
        render json: { data: exit_json(@exit) }
      else
        render_validation_error(@exit)
      end
    end

    def destroy
      @exit.destroy!
      head :no_content
    end

    private

    def set_exit
      @exit = StockExit.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: { code: "not_found", message: "イグジットが見つかりません" } }, status: :not_found
    end

    def exit_params
      params.expect(exit: [
        :stock_id, :trade_type, :judgment_type, :ai_script_id,
        :expected_price, :actual_price, :shares, :traded_at,
        :exit_reason, :review_result, :review_missed, :review_learning, :memo
      ])
    end

    def exit_json(x)
      {
        id: x.id,
        stock_id: x.stock_id,
        trade_type: x.trade_type,
        judgment_type: x.judgment_type,
        ai_script_id: x.ai_script_id,
        expected_price: x.expected_price&.to_s("F"),
        actual_price: x.actual_price&.to_s("F"),
        shares: x.shares,
        traded_at: x.traded_at&.iso8601,
        exit_reason: x.exit_reason,
        review_result: x.review_result,
        review_missed: x.review_missed,
        review_learning: x.review_learning,
        memo: x.memo,
        created_at: x.created_at.iso8601,
        updated_at: x.updated_at.iso8601
      }
    end

    def render_validation_error(record)
      render json: { error: { code: "validation_error", message: "保存できませんでした。", details: record.errors } },
             status: :unprocessable_entity
    end
  end
end
