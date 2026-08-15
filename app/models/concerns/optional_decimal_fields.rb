# frozen_string_literal: true

module OptionalDecimalFields
  extend ActiveSupport::Concern

  class_methods do
    def validates_optional_decimal(*names)
      (@optional_decimal_fields ||= []).concat(names.map(&:to_sym))

      before_validation :blank_optional_decimals_to_nil
      validate :optional_decimals_must_be_numeric

      names.each do |field_name|
        validates field_name, numericality: { greater_than: 0 }, allow_nil: true,
                              unless: -> { optional_decimal_garbage?(field_name) }
      end
    end
  end

  private

  def optional_decimal_field_names
    self.class.instance_variable_get(:@optional_decimal_fields) || []
  end

  def optional_decimal_raw(name)
    public_send("#{name}_before_type_cast")
  end

  def optional_decimal_garbage?(name)
    raw = optional_decimal_raw(name)
    return false if raw.blank? || raw.is_a?(Numeric)

    !raw.to_s.strip.match?(/\A[+-]?(?:\d+(?:\.\d+)?|\.\d+)\z/)
  end

  def blank_optional_decimals_to_nil
    optional_decimal_field_names.each do |name|
      send("#{name}=", nil) if optional_decimal_raw(name).blank?
    end
  end

  def optional_decimals_must_be_numeric
    optional_decimal_field_names.each do |name|
      next unless optional_decimal_garbage?(name)

      errors.add(name, "は数値で入力してください")
    end
  end
end
