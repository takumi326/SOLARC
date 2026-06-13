FactoryBot.define do
  factory :forecast do
    kind { :expense }
    month { Date.new(2026, 5, 1) }
    amount { 100_000 }
  end
end
