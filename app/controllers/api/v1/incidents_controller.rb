module Api
  module V1
    class IncidentsController < BaseController
      before_action :set_incident, only: %i[show update]

      def index
        criteria = Incident.recent_first
        criteria = criteria.where(status: params[:status]) if params[:status].present?
        criteria = criteria.where(severity: params[:severity]) if params[:severity].present?
        criteria = criteria.where(monitor_id: params[:monitor_id]) if params[:monitor_id].present?
        records, pagination = paginate(criteria)
        render json: { data: records.map { |incident| serialize(incident) }, pagination: }
      end

      def show
        render json: { data: serialize(@incident, detailed: true) }
      end

      def update
        status = params.require(:incident).permit(:status)[:status]
        unless Incident::STATUSES.include?(status)
          return render_error("INVALID_INCIDENT_STATUS", "Status is not supported", status: :unprocessable_content,
                              details: { allowed: Incident::STATUSES })
        end

        @incident.update!(status:)
        render json: { data: serialize(@incident, detailed: true) }
      end

      private

      def set_incident
        @incident = Incident.find(params[:id])
      end

      def serialize(incident, detailed: false)
        payload = {
          id: incident.id.to_s, monitor_id: incident.monitor_id.to_s,
          search_run_id: incident.search_run_id.to_s, incident_type: incident.incident_type,
          severity: incident.severity, title: incident.title, description: incident.description,
          path: incident.path, first_seen_at: incident.first_seen_at, last_seen_at: incident.last_seen_at,
          occurrence_count: incident.occurrence_count, status: incident.status
        }
        payload.merge!(previous_value: incident.previous_value, current_value: incident.current_value,
                       metadata: incident.metadata) if detailed
        payload
      end
    end
  end
end
