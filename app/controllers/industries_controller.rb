# frozen_string_literal: true

class IndustriesController < ApplicationController
  def index
    @industries = Industry.order(:name)
    @industry = Industry.new
  end

  def create
    @industry = Industry.new(industry_params)
    if @industry.save
      redirect_to industries_path, notice: "業種「#{@industry.name}」を追加しました。"
    else
      @industries = Industry.order(:name)
      flash.now[:alert] = @industry.errors.full_messages.join(" ")
      render :index, status: :unprocessable_entity
    end
  end

  private

  def industry_params
    params.expect(industry: [ :name ])
  end
end
