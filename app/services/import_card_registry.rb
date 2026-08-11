# frozen_string_literal: true

class ImportCardRegistry
  Card = Struct.new(
    :card_id,
    :card_name,
    :cycle,
    :source,
    :vpass_label,
    :flash_subject,
    :paypal_funding,
    :payment_method_name,
    :statement_url,
    keyword_init: true
  )

  DEFAULT_CARD_ID = "smcc_amazon"
  UNKNOWN_CARD_ID = "unknown"

  CARDS = [
    Card.new(
      card_id: "smcc_amazon",
      card_name: "Amazonカード",
      cycle: "月末締め / 翌月26日払い（三井住友カード）",
      source: "vpass",
      vpass_label: "Ａｍａｚｏｎマスター",
      flash_subject: nil,
      paypal_funding: "Mastercard-8225",
      payment_method_name: "Amazonカード",
      statement_url: "https://www.smbc-card.com/memx/web_meisai/top/index.html"
    ),
    Card.new(
      card_id: "paypay_jcb",
      card_name: "PayPayカード",
      cycle: "月末締め / 翌月27日払い（27日が金融機関休業日なら翌営業日）",
      source: "paypay_flash",
      vpass_label: nil,
      flash_subject: "PayPayカード（JCB）利用速報",
      paypal_funding: nil,
      payment_method_name: "PayPayカード",
      statement_url: "https://www.paypay-card.co.jp/member/statement/top"
    )
  ].freeze

  class << self
    def all
      CARDS
    end

    def find(card_id)
      by_id[card_id.to_s]
    end

    def card_name_for(card_id)
      card = find(card_id)
      return card.card_name if card

      card_id.to_s == UNKNOWN_CARD_ID ? "不明なカード" : card_id.to_s
    end

    def payment_method_for(card_id)
      card = find(card_id)
      return nil unless card

      PaymentMethod.find_by(name: card.payment_method_name, method_type: "card")
    end

    def resolve!(card_id, line_number: nil)
      id = card_id.to_s.strip.presence || DEFAULT_CARD_ID
      card = find(id)
      payment_method = card ? payment_method_for(id) : nil

      {
        card_id: id,
        card_name: card&.card_name || (id == UNKNOWN_CARD_ID ? "不明なカード" : id),
        payment_method: payment_method
      }
    end

    def prompt_text
      all.map { |card| format_card_for_prompt(card) }.join("\n\n")
    end

    def with_statement_url
      all.select { |card| card.statement_url.present? }
    end

    def card_id_list_text
      all.map(&:card_id).join(", ")
    end

    def workflow_summary_text
      lines = [ "対象 card_id: #{card_id_list_text}" ]
      all.each do |card|
        steps = []
        steps << "VPass（vpass_label: #{card.vpass_label}）" if card.vpass_label.present?
        steps << "PayPay速報（件名: #{card.flash_subject}）" if card.flash_subject.present?
        steps << "PayPal（支払元: #{card.paypal_funding}）" if card.paypal_funding.present?
        lines << "  #{card.card_id}: #{steps.join(' / ')}"
      end
      lines.join("\n")
    end

    private

    def by_id
      @by_id ||= all.index_by(&:card_id)
    end

    def format_card_for_prompt(card)
      lines = [
        "  card_id: #{card.card_id}",
        "    card_name     : #{card.card_name}",
        "    cycle         : #{card.cycle}",
        "    source        : #{card.source}"
      ]
      lines << "    vpass_label   : #{card.vpass_label}" if card.vpass_label.present?
      lines << "    flash_subject : #{card.flash_subject}" if card.flash_subject.present?
      lines << "    paypal_funding: #{card.paypal_funding || 'null'}"
      lines.join("\n")
    end
  end
end
