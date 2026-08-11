# frozen_string_literal: true

class DailyRoutineItemsController < ApplicationController
  before_action :ensure_defaults
  before_action :set_item, only: %i[update destroy move_up move_down]

  def index
    @items_by_slot = DailyRoutineItem.for_owner(preference_owner_key).ordered.group_by(&:slot)
  end

  def create
    attrs = create_params
    slot = attrs[:slot]
    unless DailyRoutineItem::SLOTS.include?(slot)
      redirect_to daily_routine_settings_path, alert: "不正な枠です。"
      return
    end

    position = next_position(slot)
    item = DailyRoutineItem.new(attrs.merge(owner_key: preference_owner_key, position: position))
    if item.save
      redirect_to daily_routine_settings_path, notice: "項目を追加しました。"
    else
      redirect_to daily_routine_settings_path, alert: item.errors.full_messages.join(" ")
    end
  end

  def update
    if @item.update(update_params)
      redirect_to daily_routine_settings_path, notice: "項目を更新しました。"
    else
      redirect_to daily_routine_settings_path, alert: @item.errors.full_messages.join(" ")
    end
  end

  def destroy
    @item.destroy!
    redirect_to daily_routine_settings_path, notice: "項目を削除しました。"
  end

  def move_up
    swap_with(-1)
  end

  def move_down
    swap_with(1)
  end

  private

  def ensure_defaults
    DailyRoutineItem.ensure_defaults_for!(preference_owner_key)
  end

  def set_item
    @item = DailyRoutineItem.for_owner(preference_owner_key).find(params[:id])
  end

  def create_params
    params.expect(daily_routine_item: [ :label, :slot ])
  end

  def update_params
    params.expect(daily_routine_item: [ :label ])
  end

  def next_position(slot)
    DailyRoutineItem.for_owner(preference_owner_key).in_slot(slot).maximum(:position).to_i + 1
  end

  def swap_with(direction)
    siblings = DailyRoutineItem.for_owner(preference_owner_key).in_slot(@item.slot).ordered.to_a
    index = siblings.index(@item)
    other = siblings[index + direction]
    if other
      DailyRoutineItem.transaction do
        new_pos = other.position
        other.update!(position: @item.position)
        @item.update!(position: new_pos)
      end
    end
    redirect_to daily_routine_settings_path
  end
end
