class IncidentsController < ApplicationController
  before_action :set_incident, only: %i[show acknowledge resolve update]

  def index
    @status = params[:status]
    @incidents = Incident.recent_first
    @incidents = @incidents.where(status: @status) if @status.present?
  end

  def show
    @related_runs = @incident.monitor.search_runs.recent_first.limit(10)
  end

  def update
    @incident.update!(params.require(:incident).permit(:status))
    redirect_to @incident, notice: "Incident updated."
  end

  def acknowledge
    @incident.acknowledge!
    redirect_to @incident, notice: "Incident acknowledged."
  end

  def resolve
    @incident.resolve!
    redirect_to @incident, notice: "Incident resolved."
  end

  private

  def set_incident
    @incident = Incident.find(params[:id])
  end
end
