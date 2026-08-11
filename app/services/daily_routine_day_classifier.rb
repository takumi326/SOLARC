# frozen_string_literal: true

class DailyRoutineDayClassifier
  def initialize(owner_key:, extra_off_dates: nil)
    @owner_key = owner_key
    @extra_off_dates = extra_off_dates
  end

  def off_day?(date)
    date.saturday? || date.sunday? || extra_off_dates.include?(date)
  end

  def weekend?(date)
    date.saturday? || date.sunday?
  end

  def marked_off?(date)
    extra_off_dates.include?(date)
  end

  # 連続する休みの期間（土日＋有給など）
  def off_period(date)
    return nil unless off_day?(date)

    start = date
    start -= 1 while off_day?(start - 1)
    finish = date
    finish += 1 while off_day?(finish + 1)
    start..finish
  end

  private

  def extra_off_dates
    @extra_off_dates ||= DailyRoutineOffDay.for_owner(@owner_key).pluck(:off_on).to_set
  end
end
