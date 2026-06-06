module Api
  class UserPreferencesController < ApplicationController
    def show
      row = UserPreference.find_or_initialize_by(owner_key: preference_owner_key)
      render json: { data: serialize(row) }
    end

    def update
      row = UserPreference.find_or_initialize_by(owner_key: preference_owner_key)
      submitted_keys = params.require(:user_preference).keys.map(&:to_s)
      attrs = user_preference_params

      if submitted_keys.include?("import_claude_prompt_template")
        raw = attrs[:import_claude_prompt_template]
        row.import_claude_prompt_template = raw.nil? ? nil : raw.to_s.presence
      end

      cols = UserPreference.column_names

      if submitted_keys.include?("stock_daily_hypothesis_prompt")
        raw = attrs[:stock_daily_hypothesis_prompt]
        val = raw.nil? ? nil : raw.to_s.presence
        if cols.include?("stock_daily_hypothesis_prompt")
          row[:stock_daily_hypothesis_prompt] = val
        elsif cols.include?("stock_daily_hypothesis_template")
          row[:stock_daily_hypothesis_template] = val
        end
      end

      if submitted_keys.include?("stock_daily_result_prompt") && cols.include?("stock_daily_result_prompt")
        raw = attrs[:stock_daily_result_prompt]
        row[:stock_daily_result_prompt] = raw.nil? ? nil : raw.to_s.presence
      end

      if submitted_keys.include?("stock_daily_sector_prompt") && cols.include?("stock_daily_sector_prompt")
        raw = attrs[:stock_daily_sector_prompt]
        row[:stock_daily_sector_prompt] = raw.nil? ? nil : raw.to_s.presence
      end

      if row.save
        render json: { data: serialize(row) }
      else
        render json: {
          error: { code: "validation_error", message: "Invalid user preference", details: row.errors }
        }, status: :unprocessable_entity
      end
    end

    private

    def user_preference_params
      params.require(:user_preference).permit(
        :import_claude_prompt_template,
        :stock_daily_hypothesis_prompt,
        :stock_daily_result_prompt,
        :stock_daily_sector_prompt
      )
    end

    def serialize(row)
      h = row.attributes
      {
        import_claude_prompt_template: h["import_claude_prompt_template"],
        stock_daily_hypothesis_prompt: hypothesis_prompt_for_api(h),
        stock_daily_result_prompt: h["stock_daily_result_prompt"],
        stock_daily_sector_prompt: h["stock_daily_sector_prompt"]
      }
    end

    # 新列のみ / 旧列のみ / 移行途中の DB でも NoMethodError にしない
    def hypothesis_prompt_for_api(attrs)
      if attrs.key?("stock_daily_hypothesis_prompt")
        attrs["stock_daily_hypothesis_prompt"]
      else
        attrs["stock_daily_hypothesis_template"]
      end
    end
  end
end
