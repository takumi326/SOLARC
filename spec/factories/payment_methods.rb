FactoryBot.define do
  sequence(:payment_method_name) { |n| "payment_#{n}" }

  factory :payment_method do
    name { generate(:payment_method_name) }
    method_type { "card" }
  end
end
