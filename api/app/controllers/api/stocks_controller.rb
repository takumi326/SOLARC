# frozen_string_literal: true

module Api
  class StocksController < ApplicationController
    before_action :set_stock, only: [ :show, :update, :timeline ]

    def index
      scope = Stock.includes(:industry).ordered
      if params[:q].present?
        scope = scope.search_by_term(params[:q])
      elsif params[:scope].to_s != "all"
        scope = scope.with_real_holdings
      end
      render json: { data: scope.map { |s| stock_list_json(s) } }
    end

    def show
      render json: { data: stock_detail_json(@stock) }
    end

    def update
      if @stock.update(memo: update_params[:memo])
        render json: { data: stock_detail_json(@stock) }
      else
        render_validation_error(@stock)
      end
    end

    def timeline
      trade_type = params.require(:trade_type)
      judgment_type = params.require(:judgment_type)
      ai_script_id = parse_optional_id(params[:ai_script_id])
      rows = build_timeline_rows(
        stock: @stock,
        trade_type: trade_type,
        judgment_type: judgment_type,
        ai_script_id: ai_script_id
      )
      line = current_line_for_timeline(
        stock: @stock,
        trade_type: trade_type,
        judgment_type: judgment_type,
        ai_script_id: ai_script_id
      )
      render json: { data: { rows: rows, current_line: line ? line_change_payload(line) : nil } }
    end

    def import
      file = params[:file]
      unless file.respond_to?(:read)
        render json: { error: { code: "bad_request", message: "CSV ファイル（file）を指定してください" } }, status: :bad_request
        return
      end

      result = StockCsvImporter.import!(file)
      render json: {
        data: {
          created_industries: result.created_industries,
          created_stocks: result.created_stocks,
          updated_stocks: result.updated_stocks,
          skipped_rows: result.skipped_rows
        }
      }, status: :ok
    rescue StandardError => e
      Rails.logger.error("[StockCsvImporter] #{e.class}: #{e.message}")
      render json: { error: { code: "import_failed", message: "CSV の取り込みに失敗しました。UTF-8 または Shift_JIS で、列「銘柄名・コード・業種」を含む形式か確認してください。" } },
             status: :unprocessable_entity
    end

    private

    def set_stock
      @stock = Stock.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: { code: "not_found", message: "銘柄が見つかりません" } }, status: :not_found
    end

    def update_params
      params.expect(stock: [ :memo ])
    end

    def parse_optional_id(v)
      return nil if v.blank?

      Integer(v)
    rescue ArgumentError, TypeError
      nil
    end

    def stock_list_json(stock)
      {
        id: stock.id,
        code: stock.code,
        name: stock.name,
        industry_name: stock.industry.name,
        memo: stock.memo,
        holding_shares_real: stock.holding_shares_real,
        tradingview_url: stock.tradingview_url
      }
    end

    def stock_detail_json(stock)
      stock_list_json(stock).merge(
        industry_id: stock.industry_id,
        updated_at: stock.updated_at&.iso8601
      )
    end

    def current_line_for_timeline(stock:, trade_type:, judgment_type:, ai_script_id:)
      if judgment_type.to_s == "ai" && ai_script_id.present?
        stock.current_line(trade_type: trade_type, judgment_type: judgment_type, ai_script_id: ai_script_id)
      else
        stock.current_line(trade_type: trade_type, judgment_type: judgment_type)
      end
    end

    def build_timeline_rows(stock:, trade_type:, judgment_type:, ai_script_id:)
      es = stock.entries.where(trade_type: trade_type, judgment_type: judgment_type)
      xs = stock.stock_exits.where(trade_type: trade_type, judgment_type: judgment_type)
      ls = stock.line_changes.where(trade_type: trade_type, judgment_type: judgment_type)
      if judgment_type.to_s == "ai" && ai_script_id.present?
        es = es.where(ai_script_id: ai_script_id)
        xs = xs.where(ai_script_id: ai_script_id)
        ls = ls.where(ai_script_id: ai_script_id)
      elsif judgment_type.to_s == "human"
        es = es.where(ai_script_id: nil)
        xs = xs.where(ai_script_id: nil)
        ls = ls.where(ai_script_id: nil)
      end

      rows = []
      es.find_each do |e|
        rows << trade_event_json("entry", e, sort_date_for_entry(e))
      end
      xs.find_each do |x|
        rows << trade_event_json("exit", x, sort_date_for_exit(x))
      end
      ls.find_each do |l|
        rows << trade_event_json("line_change", l, l.changed_on.to_s)
      end
      rows.sort_by! { |r| [ r[:sort_on].to_s, r[:id].to_i ] }
      rows.reverse!
      rows
    end

    def sort_date_for_entry(e)
      (e.traded_at || e.created_at.to_date).to_s
    end

    def sort_date_for_exit(x)
      (x.traded_at || x.created_at.to_date).to_s
    end

    def trade_event_json(kind, record, sort_on)
      base = { kind: kind, id: record.id, sort_on: sort_on.to_s, stock_id: record.stock_id }
      case kind
      when "entry"
        base.merge(entry_payload(record))
      when "exit"
        base.merge(exit_payload(record))
      when "line_change"
        base.merge(line_change_payload(record))
      else
        base
      end
    end

    def entry_payload(e)
      {
        trade_type: e.trade_type,
        judgment_type: e.judgment_type,
        ai_script_id: e.ai_script_id,
        expected_price: e.expected_price&.to_s("F"),
        actual_price: e.actual_price&.to_s("F"),
        shares: e.shares,
        traded_at: e.traded_at&.iso8601,
        entry_reason: e.entry_reason,
        scenario: e.scenario,
        memo: e.memo,
        created_at: e.created_at.iso8601,
        updated_at: e.updated_at.iso8601
      }
    end

    def exit_payload(x)
      {
        trade_type: x.trade_type,
        judgment_type: x.judgment_type,
        ai_script_id: x.ai_script_id,
        expected_price: x.expected_price&.to_s("F"),
        actual_price: x.actual_price&.to_s("F"),
        shares: x.shares,
        traded_at: x.traded_at&.iso8601,
        exit_reason: x.exit_reason,
        review_result: x.review_result,
        review_missed: x.review_missed,
        review_learning: x.review_learning,
        memo: x.memo,
        created_at: x.created_at.iso8601,
        updated_at: x.updated_at.iso8601
      }
    end

    def line_change_payload(l)
      {
        trade_type: l.trade_type,
        judgment_type: l.judgment_type,
        ai_script_id: l.ai_script_id,
        changed_on: l.changed_on.iso8601,
        stop_loss: l.stop_loss&.to_s("F"),
        target_price: l.target_price&.to_s("F"),
        reason: l.reason,
        created_at: l.created_at.iso8601,
        updated_at: l.updated_at.iso8601
      }
    end

    def render_validation_error(record)
      render json: { error: { code: "validation_error", message: "保存できませんでした。", details: record.errors } },
             status: :unprocessable_entity
    end
  end
end
