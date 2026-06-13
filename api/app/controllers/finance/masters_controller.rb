# frozen_string_literal: true

module Finance
  class MastersController < ApplicationController
    TABS = %w[expenses incomes categories payments].freeze

    def show
      @tab = params[:tab].presence_in(TABS) || "expenses"
    end
  end
end
