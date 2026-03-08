class DashboardController < ApplicationController
  def show
    @metrics = Metrics::Calculator.call(window: "24h")
    @active_monitors = QueryPulse::Monitor.where(enabled: true).count
    @open_incidents = Incident.active.count
    @recent_incidents = Incident.active.recent_first.limit(8)
    @recent_runs = SearchRun.recent_first.limit(8)
  end
end
