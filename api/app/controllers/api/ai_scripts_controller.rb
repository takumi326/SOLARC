# frozen_string_literal: true

module Api
  class AiScriptsController < ApplicationController
    before_action :set_script, only: [ :show, :update, :destroy ]

    def index
      rows = AiScript.order(id: :desc)
      render json: { data: rows.map { |s| script_json(s) } }
    end

    def show
      render json: { data: script_json(@script) }
    end

    def create
      script = AiScript.new(script_params)
      if script.save
        render json: { data: script_json(script) }, status: :created
      else
        render_validation_error(script)
      end
    end

    def update
      if @script.update(script_params)
        render json: { data: script_json(@script) }
      else
        render_validation_error(@script)
      end
    end

    def destroy
      @script.destroy!
      head :no_content
    end

    private

    def set_script
      @script = AiScript.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: { code: "not_found", message: "AI スクリプトが見つかりません" } }, status: :not_found
    end

    def script_params
      params.expect(ai_script: [ :version_name, :prompt ])
    end

    def script_json(s)
      {
        id: s.id,
        version_name: s.version_name,
        prompt: s.prompt,
        created_at: s.created_at.iso8601,
        updated_at: s.updated_at.iso8601
      }
    end

    def render_validation_error(record)
      render json: { error: { code: "validation_error", message: "保存できませんでした。", details: record.errors } },
             status: :unprocessable_entity
    end
  end
end
