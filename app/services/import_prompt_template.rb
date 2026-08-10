# frozen_string_literal: true

module ImportPromptTemplate
  PLACEHOLDERS = {
    catalog: "{{CATALOG}}",
    payment_method_name: "{{PAYMENT_METHOD_NAME}}",
    example_minor_id: "{{EXAMPLE_MINOR_ID}}",
    month: "{{month}}",
    merchant_rules: "{{MERCHANT_RULES}}"
  }.freeze

  DEFAULT = File.read(Rails.root.join("app/services/import_prompt_template/default.txt")).strip.freeze
  DEFAULT_MERCHANT_RULES = File.read(Rails.root.join("app/services/import_prompt_template/default_merchant_rules.txt")).strip.freeze

  module_function

  def default_normalized
    DEFAULT.gsub("\r\n", "\n").strip
  end

  def default_merchant_rules_normalized
    DEFAULT_MERCHANT_RULES.gsub("\r\n", "\n").strip
  end

  def draft_for(preference)
    preference.import_claude_prompt_template.presence || DEFAULT
  end

  def merchant_rules_for(preference)
    preference.import_merchant_rules.presence || DEFAULT_MERCHANT_RULES
  end

  def validate(template)
    text = template.to_s.strip
    return "プロンプトが空です" if text.blank?

    PLACEHOLDERS.each_value do |ph|
      return "プロンプトに #{ph} を含めてください（カテゴリ一覧・支払方法名・例の id・対象月・加盟店ルール を差し込むために必要です）" unless text.include?(ph)
    end

    nil
  end

  def normalize(template)
    template.to_s.gsub("\r\n", "\n").strip
  end

  def normalize_merchant_rules(rules)
    rules.to_s.gsub("\r\n", "\n").strip
  end
end
