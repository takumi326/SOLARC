# frozen_string_literal: true

class DailyRoutinesController < ApplicationController
  def show
    @date = Date.current
    @slots = DailyRoutineStatus.new(owner_key: preference_owner_key, date: @date).call
  end
end
