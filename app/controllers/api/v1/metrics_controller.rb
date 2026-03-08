module Api
  module V1
    class MetricsController < BaseController
      def index
        monitor = QueryPulse::Monitor.find(params[:monitor_id]) if params[:monitor_id].present?
        render json: { data: Metrics::Calculator.call(window: params.fetch(:window, "24h"), monitor:) }
      rescue ArgumentError => error
        render_error("INVALID_METRICS_WINDOW", error.message, status: :unprocessable_content,
                     details: { allowed: Metrics::Calculator::WINDOWS.keys })
      end
    end
  end
end
