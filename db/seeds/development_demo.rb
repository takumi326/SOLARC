# frozen_string_literal: true

# development 専用の動作確認用データ。再実行してもマスタは上書き・取引は存在チェックで二重化しない。
return unless Rails.env.development?

DEMO = "（デモ）"

def demo_recurring_expense!(minor_name:, major_name:, payment_name:, amount:, start_month:, memo: nil)
  major = MajorCategory.find_by!(kind: :expense, name: major_name)
  minor = MinorCategory.find_by!(major_category: major, name: minor_name)
  payment = PaymentMethod.find_by!(name: payment_name)
  expense = Expense.find_or_initialize_by(
    minor_category: minor,
    payment_method: payment,
    expense_type: :recurring,
    recurring_cycle: :monthly,
    start_month: start_month
  )
  expense.assign_attributes(amount: amount, memo: memo || "#{DEMO}定期支出")
  expense.save!
  expense
end

def demo_recurring_income!(minor_name:, major_name:, amount:, start_month:)
  major = MajorCategory.find_by!(kind: :income, name: major_name)
  minor = MinorCategory.find_by!(major_category: major, name: minor_name)
  income = Income.find_or_initialize_by(
    minor_category: minor,
    income_type: :recurring,
    start_month: start_month
  )
  income.assign_attributes(amount: amount)
  income.save!
  income
end

def demo_one_time_expense!(minor_name:, major_name:, payment_name:, month:, amount:, memo: nil)
  major = MajorCategory.find_by!(kind: :expense, name: major_name)
  minor = MinorCategory.find_by!(major_category: major, name: minor_name)
  payment = PaymentMethod.find_by!(name: payment_name)
  expense = Expense.find_or_initialize_by(
    minor_category: minor,
    payment_method: payment,
    expense_type: :one_time,
    start_month: month
  )
  expense.assign_attributes(amount: amount, end_month: month, memo: memo || "#{DEMO}単発支出")
  expense.save!

  ledger_month = payment.ledger_month_for_expense_accrual(month)
  return expense if expense.expense_transactions.joins(:ledger_transaction).exists?(transactions: { month: ledger_month })

  tx = Transaction.create!(month: ledger_month, amount: -amount)
  ExpenseTransaction.create!(expense: expense, ledger_transaction: tx)
  expense
end

puts "Seeding development demo data..."

today = Date.current
fiscal_year_start_year = today.month >= 4 ? today.year : today.year - 1
fiscal_start = Date.new(fiscal_year_start_year, 4, 1)

recurring_start = fiscal_start

demo_recurring_expense!(
  major_name: "サブスク", minor_name: "Claude", payment_name: "Amazonカード",
  amount: 3_000, start_month: recurring_start, memo: "#{DEMO}Claude Pro"
)
demo_recurring_expense!(
  major_name: "サブスク", minor_name: "YouTube Premium", payment_name: "楽天カード",
  amount: 1_280, start_month: recurring_start
)
demo_recurring_expense!(
  major_name: "サブスク", minor_name: "エニタイム", payment_name: "みずほ口座引き落とし",
  amount: 8_778, start_month: recurring_start
)
demo_recurring_income!(
  major_name: "給与", minor_name: "基本給", amount: 335_000, start_month: recurring_start
)

income_side_major = MajorCategory.find_or_create_by!(kind: :income, name: "副収入")
MinorCategory.find_or_create_by!(major_category: income_side_major, name: "（デモ）副業")
demo_recurring_income!(
  major_name: "副収入", minor_name: "（デモ）副業", amount: 20_000, start_month: recurring_start
)

# 単発（過去数ヶ月）
[ 2, 1, 0 ].each do |months_ago|
  month = today.beginning_of_month - months_ago.months
  demo_one_time_expense!(
    major_name: "ゲーム", minor_name: "Steam", payment_name: "Amazonカード",
    month: month, amount: 2_980 + (months_ago * 500), memo: "#{DEMO}Steam #{month.strftime('%Y/%m')}"
  )
end

# 今年度の定期実績を一括同期
12.times do |i|
  month = fiscal_start.advance(months: i)
  MonthlyActualsSyncService.new(month: month).call
end

# 月末残高（今年度）
12.times do |i|
  month = fiscal_start.advance(months: i)
  balance = MonthlyBalance.find_or_initialize_by(month: month)
  balance.amount = 400_000 + (i * 25_000)
  balance.save!
end

# 株デモ
semiconductor = Industry.find_or_create_by!(name: "半導体")
it_industry = Industry.find_or_create_by!(name: "IT")

[
  { code: "6758", name: "ソニーグループ", industry: semiconductor, watched: true },
  { code: "9984", name: "ソフトバンクグループ", industry: it_industry, watched: false }
].each do |attrs|
  stock = Stock.find_or_initialize_by(code: attrs[:code])
  stock.assign_attributes(
    name: attrs[:name],
    industry: attrs[:industry],
    watched: attrs[:watched],
    memo: "#{DEMO}銘柄"
  )
  stock.save!

  next if stock.entries.real.human.exists?(entry_reason: "#{DEMO}エントリー")

  stock.entries.create!(
    trade_type: :real,
    judgment_type: :human,
    traded_at: today - 45.days,
    shares: 100,
    expected_price: 3_500,
    actual_price: 3_480,
    entry_reason: "#{DEMO}エントリー",
    scenario: "決算後のトレンド継続",
    memo: "seed"
  )

  next if stock.stock_notes.exists?(title: "#{DEMO}観察メモ")

  stock.stock_notes.create!(
    noted_on: today - 7.days,
    title: "#{DEMO}観察メモ",
    note: "出来高増。サポートライン付近。"
  )
end

StockDailyNote.find_or_initialize_by(owner_key: "development", recorded_on: today).tap do |note|
  note.hypothesis ||= "#{DEMO}半導体セクターは短期調整後に反発しそう"
  note.sector_research ||= "#{DEMO}メモリ在庫は改善傾向"
  note.result ||= "#{DEMO}想定どおり小幅反発"
  note.save!
end

AiScript.find_or_initialize_by(version_name: "#{DEMO}スクリプト v1").tap do |script|
  script.prompt ||= "#{DEMO}エントリー条件: 25日線上抜け + 出来高増"
  script.save!
end

puts "Development demo data ready."
