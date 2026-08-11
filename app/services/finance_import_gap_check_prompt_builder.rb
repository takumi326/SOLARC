# frozen_string_literal: true

class FinanceImportGapCheckPromptBuilder
  def self.build(month:, existing_rows:, pending_rows:, selected_line_numbers:, duplicate_line_numbers:, catalog:, example_minor_id:)
    final_new = pending_rows.select do |row|
      row.month_label == month &&
        selected_line_numbers.include?(row.line_number) &&
        !duplicate_line_numbers.include?(row.line_number)
    end

    ledger_lines = []
    existing_rows.each do |row|
      ledger_lines << format_existing(row)
    end
    final_new.each do |row|
      ledger_lines << format_pending(row)
    end

    by_card = Hash.new { |h, k| h[k] = { count: 0, amount: 0 } }
    existing_rows.each do |row|
      key = row[:card_name].presence || "不明"
      by_card[key][:count] += 1
      by_card[key][:amount] += row[:amount].to_i
    end
    final_new.each do |row|
      key = row.card_name.presence || "不明"
      by_card[key][:count] += 1
      by_card[key][:amount] += row.amount.to_i
    end

    card_summary = by_card.sort.map do |name, stats|
      "  #{name}: #{stats[:count]} 件 / ¥#{format_amount(stats[:amount])}"
    end.join("\n")

    total_count = existing_rows.size + final_new.size
    total_amount = existing_rows.sum { |r| r[:amount].to_i } + final_new.sum(&:amount)

    <<~PROMPT.strip
      ■目的
      利用月 {{TARGET_MONTH}} について、いま手元にある台帳（下に貼付）と、
      あなたに添付するカード明細・請求画面のスクショを突き合わせ、過不足を判定する。

      重要:
      ・台帳は「利用日ベース」。明細は「売上到着日ベース」なので、月末月初は月ずれがありうる。
      ・利用通知は承認照会ベースなので、与信額と確定額の差・キャンセル無通知もありうる。
      ・それでも、スクショに明らかに載っているのに台帳に無い行は「不足」として拾う。
      ・台帳にあってスクショに無い行は、すぐ削除せず「過多候補」として理由付きで出す。
      ・status=recurring は定期として登録済み（アプリが毎月自動計上する）。
        明細に載っていても不足に挙げない。金額が違う場合だけ「金額差候補」に出す。

      ■カード定義（参考）
      {{CARDS}}

      ■いまの台帳（利用月 {{TARGET_MONTH}}）
      総合計: #{total_count} 件 / ¥#{format_amount(total_amount)}
      カード別:
      #{card_summary.presence || "  （なし）"}

      行一覧（status=saved は既にアプリ保存済み / status=pending はこれから取り込む予定）:
      #{ledger_lines.presence&.join("\n") || "（行なし）"}

      ■あなたの作業
      1. 添付スクショから、カードごとの明細行・合計を読み取る。
      2. 上の台帳と突合する（金額は完全一致を優先。日付は ±数日のずれを許容してよい）。
      3. 結果を次の形式で出す。

      ■出力（厳守）
      まず不足分だけを JSON 配列で出す（説明文・バッククォート禁止）。
      キーは取込と同じ:
        date, month, card_id, minor_category_id, amount, memo, source_id
      ・不足が0件なら [] だけ出す。
      ・memo の先頭に「[不足追加]」を付け、根拠（スクショ上の店名や日付）を短く書く。
      ・card_id はカード定義のいずれか。不明なら "unknown"。
      ・minor_category_id は下記一覧から選ぶ。不明なら未分類相当。

      JSON の後に --- を1行入れ、検算を出す:
        ・カード別: スクショ合計 / 台帳合計 / 差
        ・不足リスト（件数・金額・要約）
        ・過多候補（台帳にあってスクショに無い）
        ・金額差候補（突合できたが金額が違う）
        ・判断保留（読めない・月ずれの疑い）

      利用可能な小カテゴリ（支出）
      {{CATALOG}}

      出力例（不足が1件ある場合）:
      [{"date":"{{TARGET_MONTH}}-15","month":"{{TARGET_MONTH}}","card_id":"paypay_jcb","minor_category_id":{{EXAMPLE_MINOR_ID}},"amount":3300,"memo":"[不足追加] スクショ: 加盟店X","source_id":"gap-check-1"}]
      ---
      [paypay_jcb] スクショ合計 ¥... / 台帳合計 ¥... / 差 ¥...
      ・不足: 1件 ...
    PROMPT
      .gsub("{{TARGET_MONTH}}", month)
      .gsub("{{CARDS}}", ImportCardRegistry.prompt_text)
      .gsub("{{CATALOG}}", catalog)
      .gsub("{{EXAMPLE_MINOR_ID}}", example_minor_id.to_s)
  end

  def self.format_amount(amount)
    amount.to_i.to_fs(:delimited)
  end

  def self.format_existing(row)
    [
      "- status=#{row[:recurring] ? "recurring" : "saved"}",
      "card=#{row[:card_name]}",
      "date=#{row[:month_label]}",
      "category=#{row[:category_path]}",
      "amount=#{row[:amount]}",
      "memo=#{row[:memo].to_s.tr("\n", " ")}"
    ].join(" | ")
  end

  def self.format_pending(row)
    [
      "- status=pending",
      "No.=#{row.line_number}",
      "card_id=#{row.card_id}",
      "card=#{row.card_name}",
      "month=#{row.month_label}",
      "category=#{row.category_path}",
      "amount=#{row.amount}",
      "memo=#{row.memo.to_s.tr("\n", " ")}",
      "source_id=#{row.source_id}"
    ].join(" | ")
  end

  private_class_method :format_existing, :format_pending, :format_amount
end
