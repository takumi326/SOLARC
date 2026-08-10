# frozen_string_literal: true

class AiScriptsController < ApplicationController
  include RejectsOmittedAiTrades

  before_action :reject_omitted_ai_trades!
  before_action :set_script, only: [ :edit, :update, :destroy ]

  def index
    @scripts = AiScript.order(id: :desc)
  end

  def new
    @script = AiScript.new
  end

  def create
    @script = AiScript.new(script_params)
    if @script.save
      redirect_to ai_scripts_path, notice: "AI スクリプトを登録しました。"
    else
      flash.now[:alert] = @script.errors.full_messages.join(" ")
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @script.update(script_params)
      redirect_to ai_scripts_path, notice: "AI スクリプトを保存しました。"
    else
      flash.now[:alert] = @script.errors.full_messages.join(" ")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @script.destroy!
    redirect_to ai_scripts_path, notice: "AI スクリプトを削除しました。"
  end

  private

  def set_script
    @script = AiScript.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to ai_scripts_path, alert: "AI スクリプトが見つかりません。"
  end

  def script_params
    params.expect(ai_script: [ :version_name, :prompt ])
  end
end
