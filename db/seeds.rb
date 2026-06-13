expense_majors = [ "食費", "ソシャゲ", "雑費", "サブスク", "ゲーム" ]
income_majors = [ "給与", "副収入" ]

expense_majors.each do |name|
  MajorCategory.find_or_create_by!(kind: :expense, name: name)
end
income_majors.each do |name|
  MajorCategory.find_or_create_by!(kind: :income, name: name)
end

{
  "食費" => [ "外食", "出前館", "ウーバーイーツ" ],
  "ソシャゲ" => [ "崩壊スターレイル", "鳴潮", "ゼンレスゾーンゼロ", "アークナイツ", "エンドフィールド" ],
  "雑費" => [ "アマゾン", "UCC（コーヒー）", "宝くじ", "アマゾンプライム", "PC保証", "グーグルプレイカード" ],
  "サブスク" => [ "Line", "Note（グリーンさん）", "Google Storage", "Claude", "エニタイム", "YouTube Premium" ],
  "ゲーム" => [ "Steam", "PlayStation", "任天堂" ]
}.each do |major_name, minors|
  major = MajorCategory.find_by!(kind: :expense, name: major_name)
  minors.each do |minor_name|
    MinorCategory.find_or_create_by!(major_category: major, name: minor_name)
  end
end

{
  "給与" => [ "基本給", "賞与" ]
}.each do |major_name, minors|
  major = MajorCategory.find_by!(kind: :income, name: major_name)
  minors.each do |minor_name|
    MinorCategory.find_or_create_by!(major_category: major, name: minor_name)
  end
end

[
  { name: "楽天カード", method_type: "card", ledger_charge_timing: "next_month" },
  { name: "みずほ口座引き落とし", method_type: "bank_debit", ledger_charge_timing: "same_month" },
  { name: "ATM引き出し", method_type: "bank_withdrawal" }
].each do |attrs|
  name = attrs.fetch(:name)
  pm = PaymentMethod.find_or_initialize_by(name: name)
  pm.assign_attributes(attrs.except(:name))
  pm.save!
end

today = Date.current
fiscal_year_start_year = today.month >= 4 ? today.year : today.year - 1
fiscal_start = Date.new(fiscal_year_start_year, 4, 1)

# 今年度(4月〜翌3月)の月次予測。再seedしても(kind, month)で上書きされる。
12.times do |i|
  month = fiscal_start.advance(months: i)

  [
    { kind: :expense, amount: 200_000 },
    { kind: :income, amount: 335_000 }
  ].each do |attrs|
    forecast = Forecast.find_or_initialize_by(kind: attrs[:kind], month: month)
    forecast.amount = attrs[:amount]
    forecast.save!
  end
end

# ローカル（development）のみ: 当月の実績取引と月末残高を用意し、ダッシュボードの「実」をすぐ確認できるようにする。
# 再実行しても同じ月では取引が二重にならない（Expense/Income は find_or_initialize_by、取引は存在チェック）。
if Rails.env.development?
  demo_month = Date.current.beginning_of_month
  rakuten = PaymentMethod.find_by!(name: "楽天カード")
  expense_major = MajorCategory.find_by!(kind: :expense, name: "雑費")
  income_major = MajorCategory.find_by!(kind: :income, name: "給与")
  demo_exp_minor = MinorCategory.find_or_create_by!(major_category: expense_major, name: "（デモ）ダッシュ実績（支出）")
  demo_inc_minor = MinorCategory.find_or_create_by!(major_category: income_major, name: "（デモ）ダッシュ実績（収入）")

  demo_expense = Expense.find_or_initialize_by(
    minor_category: demo_exp_minor,
    payment_method: rakuten,
    expense_type: :one_time,
    start_month: demo_month
  )
  demo_expense.assign_attributes(
    amount: 4_800,
    end_month: demo_month,
    memo: "DB seed（development）: ダッシュの実績表示確認用"
  )
  demo_expense.save!

  demo_income = Income.find_or_initialize_by(
    minor_category: demo_inc_minor,
    income_type: :one_time,
    start_month: demo_month
  )
  demo_income.assign_attributes(amount: 150_000, end_month: demo_month)
  demo_income.save!

  unless demo_expense.expense_transactions.joins(:ledger_transaction).exists?(transactions: { month: demo_month })
    tx = Transaction.create!(month: demo_month, amount: -demo_expense.amount)
    ExpenseTransaction.create!(expense: demo_expense, ledger_transaction: tx)
  end

  unless demo_income.income_transactions.joins(:ledger_transaction).exists?(transactions: { month: demo_month })
    tx = Transaction.create!(month: demo_month, amount: demo_income.amount)
    IncomeTransaction.create!(income: demo_income, ledger_transaction: tx)
  end

  demo_balance = MonthlyBalance.find_or_initialize_by(month: demo_month)
  demo_balance.amount = 500_000
  demo_balance.save!
end
