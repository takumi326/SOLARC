class SettingsController < ApplicationController
  def show
    @preference = UserPreference.find_or_initialize_by(owner_key: preference_owner_key)
    @import_prompt_draft = ImportPromptTemplate.draft_for(@preference)
    @import_merchant_rules_draft = ImportPromptTemplate.merchant_rules_for(@preference)
  end

  def update
    @preference = UserPreference.find_or_initialize_by(owner_key: preference_owner_key)

    if params[:reset_import_prompt].present?
      @preference.import_claude_prompt_template = nil
      @preference.import_merchant_rules = nil
      if @preference.save
        redirect_to finance_settings_path, notice: "プロンプトと加盟店ルールをアプリ既定に戻しました。"
      else
        @import_prompt_draft = ImportPromptTemplate::DEFAULT
        @import_merchant_rules_draft = ImportPromptTemplate::DEFAULT_MERCHANT_RULES
        flash.now[:alert] = @preference.errors.full_messages.join(" ")
        render :show, status: :unprocessable_entity
      end
      return
    end

    raw = params.dig(:user_preference, :import_claude_prompt_template)
    normalized = ImportPromptTemplate.normalize(raw)
    default_norm = ImportPromptTemplate.default_normalized

    merchant_raw = params.dig(:user_preference, :import_merchant_rules)
    merchant_normalized = ImportPromptTemplate.normalize_merchant_rules(merchant_raw)
    merchant_default_norm = ImportPromptTemplate.default_merchant_rules_normalized

    if normalized == default_norm
      @preference.import_claude_prompt_template = nil
      @import_prompt_draft = ImportPromptTemplate::DEFAULT
      prompt_notice = "既定のプロンプトと同じ内容のため、サーバー上のカスタムを解除しました。"
    else
      error = ImportPromptTemplate.validate(normalized)
      if error
        @import_prompt_draft = raw
        @import_merchant_rules_draft = merchant_raw
        flash.now[:alert] = error
        render :show, status: :unprocessable_entity
        return
      end

      @preference.import_claude_prompt_template = normalized
      @import_prompt_draft = normalized
      prompt_notice = "保存しました。取込画面に反映されます。"
    end

    if merchant_normalized == merchant_default_norm
      @preference.import_merchant_rules = nil
      @import_merchant_rules_draft = ImportPromptTemplate::DEFAULT_MERCHANT_RULES
    else
      @preference.import_merchant_rules = merchant_normalized
      @import_merchant_rules_draft = merchant_normalized
    end

    if @preference.save
      redirect_to finance_settings_path, notice: prompt_notice
    else
      flash.now[:alert] = @preference.errors.full_messages.join(" ")
      render :show, status: :unprocessable_entity
    end
  end
end
