# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Read more: https://github.com/cyu/rack-cors

cors_origins = ENV.fetch("CORS_ORIGINS", "").split(",").map(&:strip).reject(&:blank?)
cors_origins = [ "http://localhost:5173" ] if cors_origins.empty? && Rails.env.development?

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
