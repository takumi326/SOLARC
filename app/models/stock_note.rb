# frozen_string_literal: true

class StockNote < ApplicationRecord
  belongs_to :stock

  validates :noted_on, presence: true
  validates :title, presence: true, length: { maximum: 200 }
  validates :note, presence: true
end
