# frozen_string_literal: true

# 需給/決算リスク洗い出し用。毎日の記録・実績取込のプロンプトとは別。
class StockFundamentalsPrompt
  WATCH_STOCKS = "{{WATCH_STOCKS}}"
  WATCH_PERIOD = "{{WATCH_PERIOD}}"
  TODAY = "{{TODAY}}"

  DEFAULT = <<~PROMPT.chomp
    # 目的
    チャート分析は人間側で実施済み。このプロンプトの役割は
    「チャートからは見えない決算・需給リスク」を検出し、
    エントリー除外すべき銘柄を洗い出すことに限定する。
    銘柄の推奨・選定は行わない。
    調査対象は「# 対象監視銘柄」に列挙したコード・銘柄名のみ。リスト外は扱わない。
    リストの全銘柄を抜け漏れなく調査すること。

    # 調査項目（これだけ。増やさない）
    1. 次回決算予定日 ※会社公表=◎／前年からの推定=△ を必ず区別
    2. 決算以外の確定イベント日（権利付最終日、指数入替、ロックアップ解除日）
    3. 直近3ヶ月の重要開示の有無 → 有ならタイトルと日付を一行
    4. 信用倍率と前週比の方向
    5. 空売り残高報告（0.5%以上）の有無と直近の増減
    6. 需給の重石になる進行中の事象（公募増資・CB・立会外分売・大株主売却）

    # ⚑（除外検討フラグ）※機械的に適用。解釈は書かない
    - X1: 決算日が10営業日以内、または日程が△（未確定）
    - X2: 権利付最終日・指数入替・ロックアップ解除が10営業日以内
    - X3: 公募増資・CB発行・売出が進行中、または直近3ヶ月に発表
    - X4: 信用倍率が前週比+30%以上に悪化（買残の急増＝上値のシコリ）
    - X5: 空売り残高が0.5%以上かつ増加中
    - X6: 直近3ヶ月に業績下方修正あり
    - X7: 立会外分売・大株主の売却方針が公表されている

    # 日付
    調査日: #{TODAY}
    監視期間: #{WATCH_PERIOD}

    # 対象監視銘柄
    #{WATCH_STOCKS}

    ⚑が1つ以上付いた銘柄＝「要確認」。
    付かない銘柄＝「決算・需給面で目立つ地雷なし（ただし取得不可項目は別途確認要）」

    # 出力
    ## 表（1銘柄1行）
    コード｜銘柄｜次回決算日(◎/△)｜信用倍率(前週比)｜空売り残｜⚑｜フラグ内容を一行

    ## クリーンリスト
    ⚑なしの銘柄コードのみをカンマ区切りで列挙

    ## 取得不可リスト ※最重要
    銘柄名と項目名を列挙。
    「取得できなかった＝安全」ではないことを明記すること

    ## 参照URL一覧
  PROMPT

  def self.draft_for(preference)
    stored = preference.try(:stock_fundamentals_prompt).to_s
    stored.present? ? stored : DEFAULT
  end

  def self.fill(prompt, values)
    text = prompt.to_s
    replacements = values.is_a?(Hash) ? values : { WATCH_STOCKS => values }
    replacements.each do |token, value|
      next if token.blank? || !text.include?(token)

      text = text.gsub(token, value.to_s)
    end
    text
  end
end
