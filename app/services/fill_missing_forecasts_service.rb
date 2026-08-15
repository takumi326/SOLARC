class FillMissingForecastsService
  Result = Struct.new(:created_count, keyword_init: true)

  def initialize(anchor_month:)
    @anchor = anchor_month.beginning_of_month
  end

  def call
    defaults = ForecastDefault.instance
    fiscal_start = fiscal_year_start(@anchor)
    created_count = 0

    12.times do |i|
      month_date = fiscal_start.advance(months: i)
      next if Forecast.exists?(kind: :expense, month: month_date)

      Forecast.create!(kind: :expense, month: month_date, amount: defaults.expense_amount)
      created_count += 1
    end

    Result.new(created_count: created_count)
  end

  private

  def fiscal_year_start(anchor)
    y = anchor.year
    m = anchor.month
    fiscal_year = m >= 4 ? y : y - 1
    Date.new(fiscal_year, 4, 1)
  end
end
