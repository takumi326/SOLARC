class StockDailyNotesController < ApplicationController
  VALID_FIELDS = %w[hypothesis result sector].freeze

  def index
    @notes = StockDailyNote.where(owner_key: preference_owner_key).order(recorded_on: :desc)
    preference = UserPreference.find_or_initialize_by(owner_key: preference_owner_key)
    @prompts = StockDailyPromptBuilder.prompts_from_preference(preference)
  end

  def show
    @date = parse_date!(params[:date])
    @note = StockDailyNote.find_by!(owner_key: preference_owner_key, recorded_on: @date)
  rescue ArgumentError
    redirect_to stock_daily_notes_path, alert: "日付が不正です。"
  rescue ActiveRecord::RecordNotFound
    redirect_to stock_daily_notes_path, alert: "記録が見つかりません。"
  end

  def edit_prompts
    @preference = UserPreference.find_or_initialize_by(owner_key: preference_owner_key)
    @prompts = StockDailyPromptBuilder.prompts_from_preference(@preference)
  end

  def update_prompts
    @preference = UserPreference.find_or_initialize_by(owner_key: preference_owner_key)
    attrs = prompt_params
    cols = UserPreference.column_names

    if cols.include?("stock_daily_hypothesis_prompt")
      @preference.stock_daily_hypothesis_prompt = attrs[:hypothesis].presence
    elsif cols.include?("stock_daily_hypothesis_template")
      @preference.stock_daily_hypothesis_template = attrs[:hypothesis].presence
    end
    @preference.stock_daily_result_prompt = attrs[:result].presence if cols.include?("stock_daily_result_prompt")
    @preference.stock_daily_sector_prompt = attrs[:sector].presence if cols.include?("stock_daily_sector_prompt")

    if @preference.save
      redirect_to stock_daily_notes_path, notice: "プロンプトを保存しました。"
    else
      @prompts = attrs
      flash.now[:alert] = @preference.errors.full_messages.join(" ")
      render :edit_prompts, status: :unprocessable_entity
    end
  end

  def destroy
    note = StockDailyNote.find_by(id: params[:id], owner_key: preference_owner_key)
    unless note
      redirect_to stock_daily_notes_path, alert: "記録が見つかりません。"
      return
    end

    note.destroy!
    redirect_to stock_daily_notes_path, notice: "記録を削除しました。"
  end

  def new
    @date = params[:date].present? ? parse_date!(params[:date]) : Date.current
    @note = StockDailyNote.new(recorded_on: @date)
  rescue ArgumentError
    redirect_to stock_daily_notes_path, alert: "日付が不正です。"
  end

  def create
    @date = parse_date!(params.dig(:stock_daily_note, :recorded_on))
    note = StockDailyNote.find_or_initialize_by(owner_key: preference_owner_key, recorded_on: @date)
    note.hypothesis = note_params[:hypothesis].to_s
    note.result = ""
    note.sector_research = ""

    if note.save
      redirect_to stock_daily_notes_path, notice: "記録を作成しました。"
    else
      @note = note
      flash.now[:alert] = note.errors.full_messages.join(" ")
      render :new, status: :unprocessable_entity
    end
  rescue ArgumentError
    redirect_to stock_daily_notes_path, alert: "日付が不正です。"
  end

  def edit
    @date = parse_date!(params[:date])
    @field = validate_field!(params[:field])
    @note = StockDailyNote.find_by!(owner_key: preference_owner_key, recorded_on: @date)
  rescue ArgumentError
    redirect_to stock_daily_notes_path, alert: "指定が不正です。"
  rescue ActiveRecord::RecordNotFound
    redirect_to stock_daily_notes_path, alert: "記録が見つかりません。"
  end

  def update
    @date = parse_date!(params.dig(:stock_daily_note, :recorded_on))
    @field = validate_field!(params[:field])
    note = StockDailyNote.find_by!(owner_key: preference_owner_key, recorded_on: @date)

    body = note_params[:body].to_s
    case @field
    when "hypothesis" then note.hypothesis = body
    when "result" then note.result = body
    when "sector" then note.sector_research = body
    end

    if note.save
      redirect_to stock_daily_notes_path,
                  notice: "#{StockDailyPromptBuilder::FIELD_LABELS[@field]}を保存しました。"
    else
      @note = note
      flash.now[:alert] = note.errors.full_messages.join(" ")
      render :edit, status: :unprocessable_entity
    end
  rescue ArgumentError
    redirect_to stock_daily_notes_path, alert: "指定が不正です。"
  rescue ActiveRecord::RecordNotFound
    redirect_to stock_daily_notes_path, alert: "記録が見つかりません。"
  end

  private

  def note_params
    params.expect(stock_daily_note: [ :recorded_on, :hypothesis, :body ])
  end

  def prompt_params
    raw = params.fetch(:stock_daily_prompts, {}).permit(:hypothesis, :result, :sector)
    {
      hypothesis: raw[:hypothesis].to_s,
      result: raw[:result].to_s,
      sector: raw[:sector].to_s
    }
  end

  def parse_date!(value)
    raise ArgumentError if value.blank?

    Date.iso8601(value.to_s)
  end

  def validate_field!(value)
    field = value.to_s
    raise ArgumentError unless VALID_FIELDS.include?(field)

    field
  end
end
