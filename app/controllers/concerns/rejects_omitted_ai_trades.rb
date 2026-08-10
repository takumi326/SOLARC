# frozen_string_literal: true

module RejectsOmittedAiTrades
  extend ActiveSupport::Concern

  private

  def reject_omitted_ai_trades!
    return if AiTradeFeatures.enabled?

    redirect_to stocks_path, alert: "AI 取引機能は現在オミットしています。"
  end

  def reject_omitted_ai_judgment!
    return if AiTradeFeatures.enabled?
    return unless ai_judgment_requested? || record_is_ai_judgment?

    reject_omitted_ai_trades!
  end

  def ai_judgment_requested?
    params[:judgment_type].to_s == "ai" ||
      params.dig(:entry, :judgment_type).to_s == "ai" ||
      params.dig(:exit, :judgment_type).to_s == "ai" ||
      params.dig(:stock_exit, :judgment_type).to_s == "ai" ||
      params.dig(:line_change, :judgment_type).to_s == "ai"
  end

  def record_is_ai_judgment?
    record = @entry || @exit || @line_change
    record.respond_to?(:judgment_type) && record.judgment_type.to_s == "ai"
  end
end
