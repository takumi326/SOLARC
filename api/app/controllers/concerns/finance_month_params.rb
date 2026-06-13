# frozen_string_literal: true

module FinanceMonthParams
  extend ActiveSupport::Concern

  included do
    helper_method :add_months_to_input, :month_input_value if respond_to?(:helper_method)
  end

  private

  def parse_month_param(value)
    return Date.current.beginning_of_month if value.blank?

    s = value.to_s.strip
    if s.match?(/\A\d{4}-\d{2}\z/)
      y, m = s.split("-").map(&:to_i)
      return Date.new(y, m, 1)
    end

    Date.parse(s).beginning_of_month
  rescue Date::Error
    Date.current.beginning_of_month
  end

  def month_input_value(date)
    date.strftime("%Y-%m")
  end

  def add_months_to_input(month_input, delta)
    date = parse_month_param(month_input.include?("-") && month_input.length == 7 ? month_input : "#{month_input}-01")
    month_input_value(date.advance(months: delta))
  end
end
