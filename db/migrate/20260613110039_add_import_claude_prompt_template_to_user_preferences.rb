class AddImportClaudePromptTemplateToUserPreferences < ActiveRecord::Migration[8.1]
  def change
    return if column_exists?(:user_preferences, :import_claude_prompt_template)

    add_column :user_preferences, :import_claude_prompt_template, :text
  end
end
