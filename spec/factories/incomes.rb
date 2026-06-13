FactoryBot.define do
  factory :income do
    association :minor_category
    income_type { :one_time }
    amount { 30_000 }
    start_month { Date.new(2026, 5, 1) }
    end_month { nil }
  end
end
