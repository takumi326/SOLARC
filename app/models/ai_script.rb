# frozen_string_literal: true

class AiScript < ApplicationRecord
  has_many :entries, foreign_key: :ai_script_id, inverse_of: :ai_script, dependent: :nullify
  has_many :stock_exits, foreign_key: :ai_script_id, inverse_of: :ai_script, dependent: :nullify
  has_many :line_changes, foreign_key: :ai_script_id, inverse_of: :ai_script, dependent: :nullify
  has_many :positions, foreign_key: :ai_script_id, inverse_of: :ai_script, dependent: :nullify
  has_many :trade_events, foreign_key: :ai_script_id, inverse_of: :ai_script, dependent: :nullify

  validates :version_name, presence: true, uniqueness: true, length: { maximum: 100 }
end
