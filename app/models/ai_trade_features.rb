# frozen_string_literal: true

# 仮想・AI 取引と AI スクリプト機能の出し分け。
# 既定はオミット（非表示・アクセス不可）。再有効化は ENV AI_TRADE_FEATURES=true。
module AiTradeFeatures
  module_function

  def enabled?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch("AI_TRADE_FEATURES", "false"))
  end

  def omitted?
    !enabled?
  end
end
