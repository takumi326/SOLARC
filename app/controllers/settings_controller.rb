class SettingsController < ApplicationController
  def show
    @preference = UserPreference.find_or_initialize_by(owner_key: preference_owner_key)
    @import_prompt_draft = ImportPromptTemplate.draft_for(@preference)
  end

  def update
    @preference = UserPreference.find_or_initialize_by(owner_key: preference_owner_key)
    raw = params.dig(:user_preference, :import_claude_prompt_template)
    normalized = ImportPromptTemplate.normalize(raw)
    default_norm = ImportPromptTemplate.default_normalized

    if normalized == default_norm
      @preference.import_claude_prompt_template = nil
      @import_prompt_draft = ImportPromptTemplate::DEFAULT
      notice = "既定のプロンプトと同じ内容のため、サーバー上のカスタムを解除しました。"
    else
      error = ImportPromptTemplate.validate(normalized)
      if error
        @import_prompt_draft = raw
        flash.now[:alert] = error
        render :show, status: :unprocessable_entity
        return
      end

      @preference.import_claude_prompt_template = normalized
      @import_prompt_draft = normalized
      notice = "保存しました。取込画面に反映されます。"
    end

    if @preference.save
      redirect_to finance_settings_path, notice: notice
    else
      flash.now[:alert] = @preference.errors.full_messages.join(" ")
      render :show, status: :unprocessable_entity
    end
  end
end
