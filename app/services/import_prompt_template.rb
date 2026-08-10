# frozen_string_literal: true

module ImportPromptTemplate
  PLACEHOLDERS = {
    catalog: "{{CATALOG}}",
    cards: "{{CARDS}}",
    card_workflow: "{{CARD_WORKFLOW}}",
    target_month: "{{TARGET_MONTH}}",
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

    required = %i[catalog cards target_month example_minor_id merchant_rules]
    once_only = %i[catalog cards target_month merchant_rules]

    required.each do |key|
      ph = PLACEHOLDERS[key]
      count = text.scan(ph).size
      if count.zero?
        return "プロンプトに #{ph} を含めてください（カード定義・カテゴリ一覧・対象月・例の id・加盟店ルール を差し込むために必要です）"
      end
      if once_only.include?(key) && count > 1
        return "#{ph} は1回だけにしてください（本文中の参照に使うと差し込み時に全文が繰り返し展開されます）。参照は「カード定義」「小カテゴリ一覧」と書いてください。"
      end
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
