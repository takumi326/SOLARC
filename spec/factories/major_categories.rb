FactoryBot.define do
  sequence(:major_category_name) { |n| "major_#{n}" }

  factory :major_category do
    kind { :expense }
    name { generate(:major_category_name) }
  end
end
