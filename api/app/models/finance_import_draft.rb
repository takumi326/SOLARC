# frozen_string_literal: true

class FinanceImportDraft < ApplicationRecord
  PHASES = %w[edit preview].freeze

  validates :owner_key, presence: true, uniqueness: true, length: { maximum: 255 }
  validates :phase, inclusion: { in: PHASES }

  def preview?
    phase == "preview"
  end
end
