# frozen_string_literal: true

class FinanceImportDraft < ApplicationRecord
  PHASES = %w[edit preview].freeze

  validates :owner_key, presence: true, uniqueness: true, length: { maximum: 255 }
  validates :phase, inclusion: { in: PHASES }

  class NullDraft
    attr_accessor :owner_key, :raw_json, :pending_rows, :selected_lines, :compare_month, :phase

    def initialize(owner_key:)
      @owner_key = owner_key
      @raw_json = nil
      @pending_rows = []
      @selected_lines = []
      @compare_month = nil
      @phase = "edit"
    end

    def preview?
      phase == "preview"
    end

    def persisted?
      false
    end

    def assign_attributes(attrs)
      attrs.each do |key, value|
        setter = :"#{key}="
        send(setter, value) if respond_to?(setter)
      end
    end

    def save!; end

    def update!(attrs)
      assign_attributes(attrs)
    end
  end

  def self.storage_available?
    connection.table_exists?(table_name)
  end

  def self.in_memory_for(owner_key)
    NullDraft.new(owner_key: owner_key)
  end

  def preview?
    phase == "preview"
  end
end
