# frozen_string_literal: true

class StockTradeRulesController < ApplicationController
  before_action :set_rule

  def show
  end

  def edit
  end

  def update
    if @rule.update(rule_params)
      redirect_to stock_trade_rule_path, notice: "取引ルールを保存しました。"
    else
      flash.now[:alert] = @rule.errors.full_messages.join(" ")
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_rule
    @rule = StockTradeRule.instance
  end

  def rule_params
    params.expect(stock_trade_rule: [ :body ])
  end
end
