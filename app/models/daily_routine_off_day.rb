# frozen_string_literal: true

class DailyRoutineOffDay < ApplicationRecord
  validates :owner_key, presence: true
  validates :off_on, presence: true, uniqueness: { scope: :owner_key }

  scope :for_owner, ->(owner_key) { where(owner_key: owner_key) }
  scope :covering, ->(range) { where(off_on: range) }
end
