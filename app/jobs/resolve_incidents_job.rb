class ResolveIncidentsJob < ApplicationJob
  queue_as :low

  def perform(monitor_id, seen_fingerprints: [])
    Incidents::Resolver.call(monitor: Monitor.find(monitor_id), seen_fingerprints:)
  end
end
