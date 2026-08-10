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
smbc = PaymentMethod.find_by!(name: "三井住友カード")
raise "三井住友カードがありません。db:seed を先に実行してください。" unless smbc

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
    minor_category_id: arknights.id,
    amount: 4_500,
    memo: "アークナイツ：協約起源パック（重複 — 上記と同額）",
    source_id: "18c5f2a3b4d5e6f701234567"
  },
  {
    date: "2026-07-15",
    month: IMPORT_DEMO_MONTH,
    minor_category_id: endfield.id,
    amount: 980,
    memo: "エンドフィールド 月パス",
    source_id: "18c5f2a3b4d5e6f701234568"
  },
  {
    date: "2026-07-23",
    month: IMPORT_DEMO_MONTH,
    minor_category_id: yt_premium.id,
    amount: 1_280,
    memo: "YouTube Premium",
    source_id: "2WA22952EX114591B"
  },
  {
    date: "2026-07-28",
    month: IMPORT_DEMO_MONTH,
    minor_category_id: misc.id,
    amount: 3_300,
    memo: "要確認: Mastercard加盟店",
    source_id: "18c5f2a3b4d5e6f701234569"
  }
]

verification = <<~TEXT

  ---
  ・VPass行: 2件 / ¥5,480
  ・PayPal行: 1件 / ¥1,280
  ・総合計: 4件 / ¥10,060
  ・要確認: 1件（要確認: Mastercard加盟店 ¥3,300）
  ・保留リスト: なし
  TEXT

sample_path = Rails.root.join("tmp/finance_import_sample.json")
File.write(sample_path, JSON.pretty_generate(sample_rows) + verification)

puts <<~MSG

  Import demo ready.
  - 比較月: #{IMPORT_DEMO_MONTH}
  - サンプル JSON: #{sample_path.relative_path_from(Rails.root)}
  - 取込 URL: http://localhost:3000/finance/import?prompt_month=#{IMPORT_DEMO_MONTH}

  手順:
  1. 上記 JSON をコピー
  2. /finance/import を開く（対象月 #{IMPORT_DEMO_MONTH}）
  3. JSON を貼り付け → 内容を確認
  4. 重複 1 件（アークナイツ ¥4,500）と合計サマリーを確認 → 取り込み

MSG
