require "rails_helper"

RSpec.describe ImportPromptTemplate do
  describe ".validate" do
    it "accepts default template" do
      expect(described_class.validate(described_class::DEFAULT)).to be_nil
    end

    it "rejects missing placeholder" do
      expect(described_class.validate("hello")).to include("{{CATALOG}}")
    end

    it "rejects duplicated placeholders" do
      text = described_class::DEFAULT + "\n{{CARDS}}\n"
      expect(described_class.validate(text)).to include("1回だけ")
    end
  end
end
