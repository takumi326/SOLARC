# frozen_string_literal: true

module StockTimelineRedirect
  extend ActiveSupport::Concern

  private

  def stock_timeline_path_for(stock, trade_type:, judgment_type:, ai_script_id: nil)
    stock_path(stock, trade_type: trade_type, judgment_type: judgment_type, ai_script_id: ai_script_id)
  end

  def stock_timeline_path_for_record(record)
    stock_timeline_path_for(
      record.stock,
      trade_type: record.trade_type,
      judgment_type: record.judgment_type,
      ai_script_id: record.ai_script_id
    )
  end

  def timeline_params_from_request
    {
      trade_type: params[:trade_type].presence || "real",
      judgment_type: params[:judgment_type].presence || "human",
      ai_script_id: params[:ai_script_id].presence
    }
  end
end
