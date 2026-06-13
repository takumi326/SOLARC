# frozen_string_literal: true

# entries / exits / line_changes 共通: trade_type, judgment_type, ai_script_id
module StockTradeAxes
  extend ActiveSupport::Concern

  included do
    enum :trade_type, { real: "real", virtual: "virtual" }, validate: true
    enum :judgment_type, { human: "human", ai: "ai" }, validate: true

    belongs_to :stock
    belongs_to :ai_script, optional: true

    validate :validate_trade_axes
  end

  def matches_ai_script?(other_id)
    (ai_script_id || 0) == (other_id || 0)
  end

  private

  def validate_trade_axes
    if real? && !human?
      errors.add(:judgment_type, "実取引は人間判断のみです")
    end
    if ai? && ai_script_id.blank?
      errors.add(:ai_script_id, "AI判断のときは AI スクリプトを指定してください")
    end
    errors.add(:ai_script_id, "人間判断では AI スクリプトを指定しないでください") if human? && ai_script_id.present?
  end
end
