# frozen_string_literal: true

module ImportPromptTemplate
  PLACEHOLDERS = {
    catalog: "{{CATALOG}}",
    payment_method_name: "{{PAYMENT_METHOD_NAME}}",
    example_minor_id: "{{EXAMPLE_MINOR_ID}}",
    month: "{{month}}"
  }.freeze

  DEFAULT = <<~TEXT.strip
    次の支払明細を、JSONの配列だけにしてください（説明・```・コメントは禁止）。

    1行＝単発支出1件。支払方法はすべて「{{PAYMENT_METHOD_NAME}}」固定（翌月引き落としのクレカ扱い）なので JSON には含めない。
    キーは次のとおり:
    - "month": "YYYY-MM" または "YYYY年MM月"（必須。**カード利用があった月**。例の {{month}} と同じ表記に揃える。家計簿の実績は翌暦月に計上される）
    - "minor_category_id": 数値（必須。下の一覧の id のいずれか。明細の内容に最も近い小カテゴリを選ぶ）
    - "amount": 数値（必須。円、0以上。支出はプラスの数で）
    - "memo": 文字列（任意。短いメモ）

    利用可能な小カテゴリ（支出）:
    {{CATALOG}}

    例:
    [{"month":"{{month}}","minor_category_id":{{EXAMPLE_MINOR_ID}},"amount":3500,"memo":"コンビニ"}]

    不明な行は出力しない。

    （明細をここに貼る）
  TEXT

  module_function

  def default_normalized
    DEFAULT.gsub("\r\n", "\n").strip
  end

  def draft_for(preference)
    preference.import_claude_prompt_template.presence || DEFAULT
  end

  def validate(template)
    text = template.to_s.strip
    return "プロンプトが空です" if text.blank?

    PLACEHOLDERS.each_value do |ph|
      return "プロンプトに #{ph} を含めてください（カテゴリ一覧・支払方法名・例の id・対象月 を差し込むために必要です）" unless text.include?(ph)
    end

    nil
  end

  def normalize(template)
    template.to_s.gsub("\r\n", "\n").strip
  end
end
