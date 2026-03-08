module Api
  module V1
    class MonitorsController < BaseController
      before_action :set_monitor, only: %i[show update destroy run runs]

      def index
        criteria = QueryPulse::Monitor.order_by(created_at: :desc)
        criteria = criteria.where(enabled: ActiveModel::Type::Boolean.new.cast(params[:enabled])) if params.key?(:enabled)
        records, pagination = paginate(criteria)
        render json: { data: records.map { |monitor| serialize(monitor) }, pagination: }
      end

      def show
        render json: { data: serialize(@monitor, detailed: true) }
      end

      def create
        monitor = QueryPulse::Monitor.new(monitor_params)
        if monitor.save
          render json: { data: serialize(monitor, detailed: true) }, status: :created,
                 location: api_v1_monitor_url(monitor)
        else
          render_error("INVALID_MONITOR", "Monitor validation failed", status: :unprocessable_entity,
                       details: monitor.errors.to_hash)
        end
      end

      def update
        if @monitor.update(monitor_params)
          render json: { data: serialize(@monitor, detailed: true) }
        else
          render_error("INVALID_MONITOR", "Monitor validation failed", status: :unprocessable_entity,
                       details: @monitor.errors.to_hash)
        end
      end

      def destroy
        @monitor.destroy!
        head :no_content
      end

      def run
        key = "manual:#{@monitor.id}:#{SecureRandom.uuid}"
        search_run = @monitor.search_runs.create!(status: "pending", engine: @monitor.engine,
                                                  provider: configured_provider, idempotency_key: key)
        ProcessSearchRunJob.perform_later(search_run.id.to_s)
        render json: { data: RunsController.serialize_run(search_run) }, status: :accepted
      end

      def runs
        records, pagination = paginate(@monitor.search_runs.recent_first)
        render json: { data: records.map { |run| RunsController.serialize_run(run) }, pagination: }
      end

      private

      def set_monitor
        @monitor = QueryPulse::Monitor.find(params[:id])
      end

      def monitor_params
        params.require(:monitor).permit(:name, :engine, :query, :location, :language, :country,
                                        :device, :frequency, :enabled, tags: [], assertions: {})
      end

      def serialize(monitor, detailed: false)
        payload = {
          id: monitor.id.to_s, name: monitor.name, engine: monitor.engine, query: monitor.query,
          location: monitor.location, language: monitor.language, country: monitor.country,
          device: monitor.device, frequency: monitor.frequency, enabled: monitor.enabled,
          tags: monitor.tags, next_execution_at: monitor.next_execution_at, created_at: monitor.created_at,
          updated_at: monitor.updated_at
        }
        if detailed
          payload[:assertions] = monitor.assertions
          payload[:latest_run] = RunsController.serialize_run(monitor.search_runs.recent_first.first)
          payload[:open_incident_count] = monitor.incidents.active.count
        end
        payload
      end

      def configured_provider
        ENV.fetch("SEARCH_PROVIDER", Rails.env.test? ? "fake" : @monitor.engine)
      end
    end
  end
end
