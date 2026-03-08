require "rails_helper"

RSpec.describe "API v1", type: :request do
  let(:headers) { { "CONTENT_TYPE" => "application/json" } }

  it "supports monitor CRUD with validation and pagination" do
    post "/api/v1/monitors", params: { monitor: { name: "Ruby", engine: "fake", query: "ruby scraper",
      country: "us", language: "en", device: "desktop", frequency: "15m",
      assertions: { minimum_results: 5 } } }.to_json, headers: headers
    expect(response).to have_http_status(:created)
    id = response.parsed_body.dig("data", "id")
    expect(response.parsed_body.dig("data", "assertions", "minimum_results")).to eq(5)

    get "/api/v1/monitors", params: { per_page: 1 }
    expect(response.parsed_body["pagination"]).to include("total" => 1, "per_page" => 1)

    patch "/api/v1/monitors/#{id}", params: { monitor: { frequency: "30m" } }.to_json, headers: headers
    expect(response.parsed_body.dig("data", "frequency")).to eq("30m")

    post "/api/v1/monitors", params: { monitor: { name: "Missing query" } }.to_json, headers: headers
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body.dig("error", "code")).to eq("INVALID_MONITOR")

    delete "/api/v1/monitors/#{id}"
    expect(response).to have_http_status(:no_content)
  end

  it "queues manual runs and returns run detail and diffs" do
    monitor = QueryPulse::Monitor.create!(name: "Ruby", engine: "fake", query: "ruby", country: "us")
    post "/api/v1/monitors/#{monitor.id}/run"
    expect(response).to have_http_status(:accepted)
    run_id = response.parsed_body.dig("data", "id")
    expect(enqueued_jobs.map { |job| job[:job] }).to include(ProcessSearchRunJob)

    get "/api/v1/runs/#{run_id}"
    expect(response.parsed_body.dig("data", "status")).to eq("pending")
    get "/api/v1/runs/#{run_id}/diff"
    expect(response.parsed_body.dig("data", "changes")).to eq([])
  end

  it "lists and updates incidents" do
    monitor = QueryPulse::Monitor.create!(name: "Ruby", engine: "fake", query: "ruby", country: "us")
    run = monitor.search_runs.create!(status: "success")
    incident = monitor.incidents.create!(search_run: run, incident_type: "empty_results", severity: "critical",
      title: "Empty", fingerprint: "empty", first_seen_at: Time.current, last_seen_at: Time.current)
    get "/api/v1/incidents", params: { status: "open" }
    expect(response.parsed_body["data"].first).to include("id" => incident.id.to_s, "severity" => "critical")

    patch "/api/v1/incidents/#{incident.id}", params: { incident: { status: "acknowledged" } }.to_json, headers: headers
    expect(response.parsed_body.dig("data", "status")).to eq("acknowledged")
  end

  it "returns metrics and a dependency-safe health payload" do
    allow_any_instance_of(Api::V1::HealthController).to receive(:mongodb_status).and_return("ok")
    allow_any_instance_of(Api::V1::HealthController).to receive(:redis_status).and_return("ok")
    get "/api/v1/metrics", params: { window: "24h" }
    expect(response.parsed_body["data"]).to include("request_count" => 0, "success_rate" => 0.0)
    get "/api/v1/health"
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "dependencies")).to include("mongodb" => "ok", "redis" => "ok")
  end
end
