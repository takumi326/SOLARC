# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Stocks", type: :request do
  let(:headers) { { "HOST" => "www.example.com" } }

  describe "GET /api/stocks" do
    it "returns an empty list when no stocks exist" do
      get "/api/stocks", headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["data"]).to eq([])
    end
  end

  describe "POST /api/stocks/import" do
    it "imports UTF-8 CSV from multipart upload" do
      csv = <<~CSV
        銘柄名,コード,業種
        ニッスイ,1332,水産・農林業
      CSV
      file = Rack::Test::UploadedFile.new(
        StringIO.new(csv),
        "text/csv",
        original_filename: "jpx400.csv"
      )

      post "/api/stocks/import", params: { file: file }, headers: headers

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)["data"]
      expect(data["created_stocks"]).to eq(1)
      expect(Stock.find_by(code: "1332")&.name).to eq("ニッスイ")
    end
  end
end
