# Avoid CORS issues when API is called from an external frontend.
# Rails HTML 本番は同一オリジンのため CORS 不要。`CORS_ORIGINS` があるときだけ有効化する。
# Read more: https://github.com/cyu/rack-cors

cors_origins = ENV.fetch("CORS_ORIGINS", "").split(",").map(&:strip).reject(&:blank?)

if cors_origins.any?
  Rails.application.config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins(*cors_origins)

      resource "*",
        headers: :any,
        credentials: true,
        methods: [ :get, :post, :put, :patch, :delete, :options, :head ]
    end
  end
end
