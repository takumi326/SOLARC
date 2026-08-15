# frozen_string_literal: true

module TradeEventCrud
  extend ActiveSupport::Concern

  private

  def event_attrs_from(permitted)
    h = permitted.to_h.symbolize_keys
    h[:quantity] = h.delete(:shares) if h.key?(:shares)
    h[:take_profit] = h.delete(:target_price) if h.key?(:target_price)
    h.delete(:traded_at)
    h.delete(:changed_on)
    h.compact_blank
  end

  def executed_at_from(date_value)
    return Time.current if date_value.blank?

    date = date_value.to_date
    now = Time.current
    Time.zone.local(date.year, date.month, date.day, now.hour, now.min, now.sec)
  rescue ArgumentError, TypeError
    Time.current
  end

  def update_trade_event!(event, attrs, executed_at)
    event.assign_attributes(attrs)
    event.executed_at = executed_at if executed_at.present?
    saved = event.save
    PositionRecalculator.new(event.position.reload).call if saved && event.position
    saved
  end

  def destroy_trade_event!(event)
    position = event.position
    event.destroy!
    if position
      position.reload
      if position.trade_events.empty?
        position.destroy!
      else
        PositionRecalculator.new(position).call
      end
    end
  end

  def parse_optional_id(v)
    return nil if v.blank?

    Integer(v)
  rescue ArgumentError, TypeError
    nil
  end
end
