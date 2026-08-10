# frozen_string_literal: true

class StockTradeRulesController < ApplicationController
  before_action :set_rule, only: [ :show, :edit, :update, :destroy ]

  def index
    @rules = StockTradeRule.order(updated_at: :desc, id: :desc)
  end

  def show
  end

  def new
    @rule = StockTradeRule.new
  end

  def create
    @rule = StockTradeRule.new(rule_params)
    if @rule.save
      redirect_to stock_trade_rule_path(@rule), notice: "取引ルールを登録しました。"
    else
      flash.now[:alert] = @rule.errors.full_messages.join(" ")
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @rule.update(rule_params)
      redirect_to stock_trade_rule_path(@rule), notice: "取引ルールを保存しました。"
    else
      flash.now[:alert] = @rule.errors.full_messages.join(" ")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @rule.destroy!
    redirect_to stock_trade_rules_path, notice: "取引ルールを削除しました。"
  end

  private

  def set_rule
    @rule = StockTradeRule.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to stock_trade_rules_path, alert: "取引ルールが見つかりません。"
  end

  def rule_params
    params.expect(stock_trade_rule: [ :title, :body ])
  end
end
