module Api
  module V1
    class RunsController < BaseController
      before_action :set_run

      def show
        render json: { data: self.class.serialize_run(@run, detailed: true) }
      end

      def diff
        previous = @run.started_at && @run.monitor.search_runs.where(:started_at.lt => @run.started_at).recent_first.first
        render json: {
          data: {
            run_id: @run.id.to_s,
            previous_run_id: previous&.id&.to_s,
            schema_changed: previous.present? && previous.schema_fingerprint != @run.schema_fingerprint,
            changes: @run.changes,
            summary: Array(@run.changes).group_by { |change| change["type"] }.transform_values(&:count)
          }
        }
      end

      def self.serialize_run(run, detailed: false)
        return nil unless run

        payload = {
          id: run.id.to_s, monitor_id: run.monitor_id.to_s, status: run.status, engine: run.engine,
          provider: run.provider, started_at: run.started_at, completed_at: run.completed_at,
          http_status: run.http_status, response_time_ms: run.response_time_ms,
          result_count: run.result_count, schema_fingerprint: run.schema_fingerprint,
          relevance_score: run.relevance_score, error_type: run.error_type, error_message: run.error_message,
          created_at: run.created_at
        }
        if detailed
          payload.merge!(normalized_response: run.normalized_response, raw_response: run.raw_response,
                         changes: run.changes, assertion_results: run.assertion_results,
                         diagnostics: run.diagnostics)
        end
        payload
      end

      private

      def set_run
        @run = SearchRun.find(params[:id])
      end
    end
  end
end
