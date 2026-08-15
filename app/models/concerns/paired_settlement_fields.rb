# frozen_string_literal: true

# 約定するときは株数・約定価格・約定日をセットにする
module PairedSettlementFields
  extend ActiveSupport::Concern

  included do
    validate :settlement_price_and_date_together
    validate :traded_at_not_in_the_future
    validate :expected_or_actual_price_present
  end

  private

  def expected_or_actual_price_present
    return if expected_price.present? || actual_price.present?

    errors.add(:base, "予定価格か約定価格のどちらかを入力してください")
  end

  def settlement_price_and_date_together
    has_price = actual_price.present?
    has_date = traded_at.present?
    has_shares = shares.present?
    settling = has_price || has_date
    return unless settling
    return if has_price && has_date && has_shares

    errors.add(:base, "約定するときは株数・約定価格・約定日をセットで入力してください")
  end

  def traded_at_not_in_the_future
    return if traded_at.blank?
    return if traded_at <= Time.zone.today

    errors.add(:traded_at, "は今日以前の日付にしてください")
  end
end
