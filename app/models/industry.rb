# frozen_string_literal: true

class Industry < ApplicationRecord
  has_many :stocks, dependent: :restrict_with_exception

  validates :name, presence: true, uniqueness: true, length: { maximum: 100 }
end
