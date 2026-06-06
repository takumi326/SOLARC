# frozen_string_literal: true

module Api
  class EntriesController < ApplicationController
    before_action :set_entry, only: [ :show, :update, :destroy ]

    def show
      render json: { data: entry_json(@entry) }
    end

    def create
      line = initial_line_hash
      entry = Entry.new(entry_params)
      begin
        ActiveRecord::Base.transaction do
          entry.save!
          create_initial_line_change!(entry, line) if line.present?
        end
      rescue ActiveRecord::RecordInvalid => e
        return render_validation_error(e.record)
      end
      render json: { data: entry_json(entry) }, status: :created
    end

    def update
      if @entry.update(entry_params)
        render json: { data: entry_json(@entry) }
      else
        render_validation_error(@entry)
      end
    end

    def destroy
      @entry.destroy!
      head :no_content
    end

    private

    def set_entry
      @entry = Entry.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: { code: "not_found", message: "エントリーが見つかりません" } }, status: :not_found
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

    def entry_json(e)
      {
        id: e.id,
        stock_id: e.stock_id,
        trade_type: e.trade_type,
        judgment_type: e.judgment_type,
        ai_script_id: e.ai_script_id,
        expected_price: e.expected_price&.to_s("F"),
        actual_price: e.actual_price&.to_s("F"),
        shares: e.shares,
        traded_at: e.traded_at&.iso8601,
        entry_reason: e.entry_reason,
        scenario: e.scenario,
        memo: e.memo,
        created_at: e.created_at.iso8601,
        updated_at: e.updated_at.iso8601
      }
    end

    def render_validation_error(record)
      render json: { error: { code: "validation_error", message: "保存できませんでした。", details: record.errors } },
             status: :unprocessable_entity
    end
  end
end
