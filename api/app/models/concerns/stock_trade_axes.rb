# frozen_string_literal: true

# entries / exits / line_changes 共通: trade_type, judgment_type（human のみ）
module StockTradeAxes
  extend ActiveSupport::Concern

  included do
    enum :trade_type, { real: "real", virtual: "virtual" }, validate: true
    enum :judgment_type, { human: "human" }, validate: true

    belongs_to :stock

    validate :validate_trade_axes
  end

  private

  def validate_trade_axes
    errors.add(:judgment_type, "実取引は人間判断のみです") if real? && !human?
  end
end
