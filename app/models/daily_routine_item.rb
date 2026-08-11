# frozen_string_literal: true

class DailyRoutineItem < ApplicationRecord
  SLOTS = %w[weekday_morning weekday_evening holiday month_end].freeze

  SLOT_LABELS = {
    "weekday_morning" => "平日朝",
    "weekday_evening" => "平日夜",
    "holiday" => "休日",
    "month_end" => "月末"
  }.freeze

  DEFAULT_LABELS = {
    "weekday_morning" => [
      "グリーンさんの Discord 確認",
      "ロイターの新着ニュース確認",
      "米株・日本株先物確認",
      "本日の決算・イベント確認",
      "SOLARC に上記をまとめて記載"
    ],
    "weekday_evening" => [
      "（所有していたら）所有株のチャート確認",
      "日経平均・TOPIX の確認",
      "セクターの確認（資金の流れ）",
      "SOLARC に上記をまとめて記載"
    ],
    "holiday" => [
      "グリーンさんの休日記事確認",
      "前週エントリーした銘柄の検証",
      "前週エントリーしなかった監視銘柄の検証",
      "チャートから監視銘柄の選定",
      "監視銘柄をセクターで選別",
      "監視銘柄を決算/イベントで選別",
      "監視銘柄を需給で選別",
      "監視銘柄のエントリー計画を SOLARC に登録",
      "楽天証券に監視銘柄を登録"
    ],
    "month_end" => [
      "カード明細を用意する",
      "プロンプトをコピーして Claude で JSON を作る",
      "JSON を実績取込に貼って内容を確認",
      "過不足チェックで不足分を追加",
      "選択した行を取り込む",
      "月末残高を登録"
    ]
  }.freeze

  validates :owner_key, presence: true
  validates :slot, inclusion: { in: SLOTS }
  validates :label, presence: true, length: { maximum: 255 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :for_owner, ->(owner_key) { where(owner_key: owner_key) }
  scope :in_slot, ->(slot) { where(slot: slot) }
  scope :ordered, -> { order(:position, :id) }

  def self.ensure_defaults_for!(owner_key)
    return if for_owner(owner_key).exists?

    transaction do
      DEFAULT_LABELS.each do |slot, labels|
        labels.each_with_index do |label, index|
          create!(owner_key: owner_key, slot: slot, label: label, position: index)
        end
      end
    end
  end

  def slot_label
    SLOT_LABELS[slot] || slot
  end
end
