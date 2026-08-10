# frozen_string_literal: true

require "rails_helper"

RSpec.describe ImportCardRegistry do
  describe ".resolve!" do
    let!(:smcc) { create(:payment_method, name: "Amazonカード", method_type: "card") }
    let!(:paypay) { create(:payment_method, name: "PayPayカード", method_type: "card") }

    it "maps smcc_amazon to payment method" do
      result = described_class.resolve!( "smcc_amazon", line_number: 1)
      expect(result[:card_name]).to eq("Amazonカード")
      expect(result[:payment_method]).to eq(smcc)
    end

    it "maps paypay_jcb to payment method" do
      result = described_class.resolve!("paypay_jcb", line_number: 2)
      expect(result[:payment_method]).to eq(paypay)
    end

    it "defaults missing card_id to smcc_amazon" do
      result = described_class.resolve!(nil)
      expect(result[:card_id]).to eq("smcc_amazon")
    end

    it "does not raise when payment method master is missing" do
      PaymentMethod.delete_all
      result = described_class.resolve!("smcc_amazon", line_number: 1)
      expect(result[:card_id]).to eq("smcc_amazon")
      expect(result[:payment_method]).to be_nil
    end

    it "does not raise for unknown card_id" do
      result = described_class.resolve!("mystery", line_number: 3)
      expect(result[:card_id]).to eq("mystery")
      expect(result[:payment_method]).to be_nil
    end
  end
end
