require "rails_helper"

RSpec.describe Search::ExecuteMonitor do
  it "persists a normalized snapshot, assertion output and relevance score" do
    monitor = QueryPulse::Monitor.create!(name: "Ruby", engine: "fake", query: "ruby scraper", country: "us",
                              assertions: { minimum_results: 5, required_domains: ["github.com"] })
    run = described_class.call(monitor:, adapter: Search::FakeAdapter.new, idempotency_key: "test:1")

    expect(run.status).to eq("success")
    expect(run.snapshot.normalized_data["organic_results"].length).to eq(6)
    expect(run.schema_fingerprint).to eq(run.snapshot.schema_hash)
    expect(run.assertion_results.find { |result| result["assertion"] == "minimum_results" }).to include("passed" => true)
    expect(run.assertion_results.find { |result| result["assertion"] == "required_domains" }).to include("passed" => false)
    expect(run.monitor.incidents.first.incident_type).to eq("domain_mismatch")
    expect(run.relevance_score).to be_between(0, 100)
  end
end
