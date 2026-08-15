# frozen_string_literal: true

class StockSettingsController < ApplicationController
  before_action :set_setting

  def show
  end

  def update
    if @setting.update(setting_params)
      redirect_to stock_setting_path, notice: "設定を保存しました。"
    else
      flash.now[:alert] = @setting.errors.full_messages.join(" ")
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_setting
    @setting = StockSetting.instance
  end

  def setting_params
    params.expect(stock_setting: [ :tradingview_chart_id ])
  end
end
