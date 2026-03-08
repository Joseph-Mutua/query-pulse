require "rails_helper"

RSpec.describe Metrics::Calculator do
  it "calculates actual rates and latency percentiles for the requested window" do
    monitor = QueryPulse::Monitor.create!(name: "Ruby", engine: "fake", query: "ruby", country: "us")
    [100, 200, 300, 400].each_with_index do |latency, index|
      monitor.search_runs.create!(status: index == 3 ? "failed" : "success", started_at: 10.minutes.ago,
                                  response_time_ms: latency, result_count: 5)
    end
    metrics = described_class.call(window: "1h", monitor:)

    expect(metrics).to include("request_count" => 4, "success_count" => 3, "success_rate" => 75.0,
                               "average_latency_ms" => 250.0, "p95_latency_ms" => 400,
                               "average_result_count" => 5.0)
  end
end
