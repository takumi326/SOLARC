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
      %i[expense income].each do |kind|
        next if Forecast.exists?(kind: kind, month: month_date)

        amount = kind == :expense ? defaults.expense_amount : defaults.income_amount
        Forecast.create!(kind: kind, month: month_date, amount: amount)
        created_count += 1
      end
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
