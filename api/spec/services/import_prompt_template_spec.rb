require "rails_helper"

RSpec.describe ImportPromptTemplate do
  describe ".validate" do
    it "accepts default template" do
      expect(described_class.validate(described_class::DEFAULT)).to be_nil
    end

    it "rejects missing placeholder" do
      expect(described_class.validate("hello")).to include("{{CATALOG}}")
    end
  end
end
