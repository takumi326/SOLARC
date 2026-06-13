FactoryBot.define do
  sequence(:minor_category_name) { |n| "minor_#{n}" }

  factory :minor_category do
    association :major_category
    name { generate(:minor_category_name) }
  end
end
