# frozen_string_literal: true

# development 専用: メール取込（/finance/import）の動作確認用データとサンプル JSON。
return unless Rails.env.development?

IMPORT_DEMO = "（デモ）"
IMPORT_DEMO_MONTH = "2026-07"

def import_demo_one_time!(minor:, payment:, month:, amount:, memo:)
  expense = Expense.find_or_initialize_by(
    minor_category: minor,
    payment_method: payment,
    expense_type: :one_time,
    start_month: month
  )
  expense.assign_attributes(amount: amount, end_month: month, memo: memo)
  expense.save!

  ledger_month = payment.ledger_month_for_expense_accrual(month)
  unless expense.expense_transactions.joins(:ledger_transaction).exists?(transactions: { month: ledger_month })
    tx = Transaction.create!(month: ledger_month, amount: -amount)
    ExpenseTransaction.create!(expense: expense, ledger_transaction: tx)
  end
  expense
end

puts "Seeding development import demo (#{IMPORT_DEMO_MONTH})..."

demo_month = Date.parse("#{IMPORT_DEMO_MONTH}-01")
smbc = PaymentMethod.find_by(name: "Amazonカード")
raise "Amazonカードがありません。db:seed を先に実行してください。" unless smbc

minors = MinorCategory.joins(:major_category).where(major_categories: { kind: :expense }).index_by(&:name)
arknights = minors.fetch("アークナイツ")
endfield = minors.fetch("エンドフィールド")
yt_premium = minors["YouTube Premium"] || minors.fetch("未分類")
misc = minors.fetch("未分類")

# 重複確認用: 取込 JSON に同じカテゴリ・金額の行を入れるとプレビューで除外される
import_demo_one_time!(
  minor: arknights,
  payment: smbc,
  month: demo_month,
  amount: 4_500,
  memo: "#{IMPORT_DEMO}取込済み（重複テスト用）"
)

sample_rows = [
  {
    date: "2026-07-20",
    month: IMPORT_DEMO_MONTH,
    card_id: "smcc_amazon",
    minor_category_id: arknights.id,
    amount: 4_500,
    memo: "アークナイツ：協約起源パック（重複 — 上記と同額）",
    source_id: "18c5f2a3b4d5e6f701234567"
  },
  {
    date: "2026-07-15",
    month: IMPORT_DEMO_MONTH,
    card_id: "smcc_amazon",
    minor_category_id: endfield.id,
    amount: 980,
    memo: "エンドフィールド 月パス",
    source_id: "18c5f2a3b4d5e6f701234568"
  },
  {
    date: "2026-07-23",
    month: IMPORT_DEMO_MONTH,
    card_id: "smcc_amazon",
    minor_category_id: yt_premium.id,
    amount: 1_280,
    memo: "YouTube Premium",
    source_id: "2WA22952EX114591B"
  },
  {
    date: "2026-07-28",
    month: IMPORT_DEMO_MONTH,
    card_id: "paypay_jcb",
    minor_category_id: misc.id,
    amount: 3_300,
    memo: "要確認: PayPay加盟店",
    source_id: "19fc78a82c123bce"
  }
]

verification = <<~TEXT

  ---
  [smcc_amazon] Amazonカード
    ・VPass: 2件 / ¥5,480
    ・PayPal: 1件 / ¥1,280
    ・小計: 3件 / ¥6,760
  [paypay_jcb] PayPayカード
    ・PayPay速報: 1件 / ¥3,300
    ・小計: 1件 / ¥3,300
  ・総合計: 4件 / ¥10,060
  TEXT

sample_path = Rails.root.join("tmp/finance_import_sample.json")
File.write(sample_path, JSON.pretty_generate(sample_rows) + verification)

gap_rows = [
  {
    date: "2026-07-10",
    month: IMPORT_DEMO_MONTH,
    card_id: "smcc_amazon",
    minor_category_id: misc.id,
    amount: 1_980,
    memo: "[不足追加] Amazon.co.jp 書籍",
    source_id: "18c5f2a3b4d5e6f701234570"
  },
  {
    date: "2026-07-25",
    month: IMPORT_DEMO_MONTH,
    card_id: "paypay_jcb",
    minor_category_id: misc.id,
    amount: 540,
    memo: "[不足追加] コンビニ（スクショ）",
    source_id: "19fc78a82c123bcf"
  }
]

gap_verification = <<~TEXT

  ---
  不足分（過不足チェック結果）
  [smcc_amazon] Amazonカード
    ・VPass: 1件 / ¥1,980
    ・小計: 1件 / ¥1,980
  [paypay_jcb] PayPayカード
    ・PayPay速報: 1件 / ¥540
    ・小計: 1件 / ¥540
  ・不足合計: 2件 / ¥2,520
  TEXT

gap_path = Rails.root.join("tmp/finance_import_sample_gap.json")
File.write(gap_path, JSON.pretty_generate(gap_rows) + gap_verification)

puts <<~MSG

  Import demo ready.
  - 比較月: #{IMPORT_DEMO_MONTH}
  - サンプル JSON: #{sample_path.relative_path_from(Rails.root)}
  - 不足分 JSON: #{gap_path.relative_path_from(Rails.root)}
  - 取込 URL: http://localhost:3000/finance/import?prompt_month=#{IMPORT_DEMO_MONTH}

  手順:
  1. サンプル JSON をコピーして /finance/import に貼る → 内容を確認
  2. 重複 1 件（アークナイツ ¥4,500）を確認
  3. 不足分 JSON を「不足分 JSON を追加」に貼って候補に追加
  4. 支払方法を確認して取り込む

MSG
