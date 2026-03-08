require "sidekiq/api"

module Api
  module V1
    class HealthController < BaseController
      def show
        dependencies = { mongodb: mongodb_status, redis: redis_status }
        dependencies[:background_processing] = sidekiq_status
        healthy = dependencies.values.none? { |status| %w[error unavailable].include?(status) }
        render json: { data: { status: healthy ? "ok" : "degraded", dependencies:, timestamp: Time.current } },
               status: healthy ? :ok : :service_unavailable
      end

      private

      def mongodb_status
        Mongoid.default_client.database.command(ping: 1).first["ok"] == 1.0 ? "ok" : "error"
      rescue StandardError
        "error"
      end

      def redis_status
        client = Redis.new(url: ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379/0"), connect_timeout: 1, read_timeout: 1)
        client.ping == "PONG" ? "ok" : "error"
      rescue StandardError
        "error"
      ensure
        client&.close
      end

      def sidekiq_status
        return "unavailable" unless redis_status == "ok"

        Sidekiq::ProcessSet.new.size.positive? ? "available" : "unavailable"
      rescue StandardError
        "unavailable"
      end
    end
  end
end
