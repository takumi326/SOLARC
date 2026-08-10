# frozen_string_literal: true

class FinanceImportClaudePromptBuilder
  FIXED_PAYMENT_METHOD_NAME = "三井住友カード"

  def self.build(catalog:, example_minor_id:, month:, saved_template: nil, merchant_rules: nil)
    base = saved_template.presence || ImportPromptTemplate::DEFAULT
    month_label = format_month_for_prompt(month)
    rules = merchant_rules.presence || ImportPromptTemplate::DEFAULT_MERCHANT_RULES
    base
      .gsub(ImportPromptTemplate::PLACEHOLDERS[:catalog], catalog)
      .gsub(ImportPromptTemplate::PLACEHOLDERS[:payment_method_name], FIXED_PAYMENT_METHOD_NAME)
      .gsub(ImportPromptTemplate::PLACEHOLDERS[:example_minor_id], example_minor_id.to_s)
      .gsub(ImportPromptTemplate::PLACEHOLDERS[:month], month_label)
      .gsub(ImportPromptTemplate::PLACEHOLDERS[:merchant_rules], rules)
  end

  def self.format_month_for_prompt(iso_yyyy_mm)
    compact = iso_yyyy_mm.to_s.strip.slice(0, 7)
    return iso_yyyy_mm.to_s.strip unless compact.match?(/\A\d{4}-\d{2}\z/)

    compact
  end

  private_class_method :format_month_for_prompt
end
