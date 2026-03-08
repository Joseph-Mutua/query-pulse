require "rails_helper"

RSpec.describe Incidents::Detector do
  it "deduplicates recurring findings and increments occurrence count" do
    monitor = QueryPulse::Monitor.create!(name: "Ruby", engine: "fake", query: "ruby", country: "us")
    run = monitor.search_runs.create!(status: "success", result_count: 1)
    comparison = { changes: [{ path: "organic_results[].price", type: "FIELD_REMOVED", previous: "$10", current: nil, severity: "warning" }] }

    2.times { described_class.call(monitor:, search_run: run, comparison:) }
    expect(monitor.incidents.count).to eq(1)
    expect(Incident.first.reload).to have_attributes(incident_type: "field_removed", occurrence_count: 2)
  end

  it "resolves active incidents after consecutive healthy executions" do
    monitor = QueryPulse::Monitor.create!(name: "Ruby", engine: "fake", query: "ruby", country: "us")
    run = monitor.search_runs.create!(status: "success", result_count: 1)
    incident = monitor.incidents.create!(search_run: run, incident_type: "field_removed", severity: "warning",
      title: "Missing", path: "item.price", fingerprint: "abc", first_seen_at: Time.current, last_seen_at: Time.current)

    3.times { Incidents::Resolver.call(monitor:, seen_fingerprints: []) }
    expect(incident.reload.status).to eq("resolved")
  end
end
