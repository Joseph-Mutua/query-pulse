puts "Resetting QueryPulse demo records..."
QueryPulse::Monitor.where(tags: "demo").destroy_all

definitions = [
  ["GitHub Ruby Results", "site:github.com \"ruby scraper\"", { "minimum_results" => 5, "required_domains" => ["github.com"], "title_contains" => ["ruby"] }],
  ["Ruby Documentation", "ruby documentation", { "minimum_results" => 5 }],
  ["Rails Security Guides", "rails security guide", { "minimum_results" => 4, "maximum_response_time_ms" => 4_000 }],
  ["Mongoid References", "mongoid embedded documents", { "minimum_results" => 5 }],
  ["Sidekiq Reliability", "sidekiq retry reliability", { "minimum_results" => 5 }],
  ["API Monitoring", "search api monitoring", { "minimum_results" => 5 }],
  ["Search Schema Watch", "structured search response", { "minimum_results" => 5 }],
  ["Rare Query Watch", "rare deterministic query", { "minimum_results" => 3 }]
]

monitors = definitions.map.with_index do |(name, query, assertions), index|
  QueryPulse::Monitor.create!(name:, query:, assertions:, engine: "fake", location: index.even? ? "Austin, Texas" : "New York, New York",
                              language: "en", country: "us", device: index % 3 == 0 ? "mobile" : "desktop",
                              frequency: %w[5m 15m 30m 1h][index % 4], enabled: true, tags: ["demo"])
end

def normalized_data(monitor, domains:, latency:, empty: false, degraded: false)
  results = if empty
              []
            else
              domains.each_with_index.map do |domain, index|
                number = index + 1
                item = { "position" => degraded && index.zero? ? 8 : number,
                         "title" => "Ruby scraper result #{number}",
                         "link" => "https://#{domain}/querypulse/result-#{number}",
                         "displayed_link" => domain, "domain" => domain,
                         "snippet" => "A deterministic Ruby search result for reliability testing.",
                         "price" => "$#{number * 10}" }
                item.delete("snippet") if degraded && index == 1
                item["price"] = { "amount" => number * 10, "currency" => "USD" } if degraded && index == 2
                item
              end
            end
  { "search_metadata" => { "engine" => monitor.engine, "query" => monitor.query, "location" => monitor.location,
                             "language" => monitor.language, "device" => monitor.device, "response_time_ms" => latency },
    "organic_results" => results, "related_questions" => ["How does QueryPulse detect search changes?"],
    "related_searches" => ["search API monitoring"],
    "provider_data" => { "search_metadata" => { "id" => SecureRandom.hex(8) } } }
end

def persist_demo_run(monitor, data, started_at)
  latency = data.dig("search_metadata", "response_time_ms")
  run = monitor.search_runs.create!(status: "success", started_at:, completed_at: started_at + (latency / 1_000.0),
                                    http_status: 200, response_time_ms: latency, result_count: data.fetch("organic_results").length,
                                    engine: monitor.engine, provider: "fake", normalized_response: data, raw_response: data)
  previous = monitor.snapshots.recent_first.first
  current = Comparison::SnapshotBuilder.call(monitor:, search_run: run, normalized_data: data)
  comparison = previous ? Comparison::ResultComparator.call(previous:, current:) : { "changes" => [], "summary" => {} }
  assertion_results = Assertions::Evaluator.call(data:, assertions: monitor.assertions, response_time_ms: run.response_time_ms)
  relevance = Assertions::RelevanceScorer.call(data:, query: monitor.query, assertions: monitor.assertions, assertion_results:)
  run.set(schema_fingerprint: current.schema_hash, response_changes: comparison["changes"], assertion_results:,
          relevance_score: relevance["score"], diagnostics: { "comparison_summary" => comparison["summary"], "relevance" => relevance })
  Incidents::Detector.call(monitor:, search_run: run, previous:, current:, comparison:, assertion_results:,
                           performance_metrics: Metrics::LatencyRegression.call(monitor:))
end

monitors.each_with_index do |monitor, monitor_index|
  30.times do |run_index|
    started_at = (30 - run_index).hours.ago
    latency = 850 + (monitor_index * 90) + ((run_index * 137) % 500)
    latency = 5_200 + ((run_index * 73) % 900) if monitor_index.zero? && run_index >= 20
    empty = monitor_index == 7 && run_index == 29
    degraded = monitor_index.zero? && run_index == 29
    domains = degraded ? %w[github.com example.net unexpected.test docs.example.org spam.invalid github.com] : Array.new(6, "github.com")
    persist_demo_run(monitor, normalized_data(monitor, domains:, latency:, empty:, degraded:), started_at)
  end
end

metrics = Metrics::Calculator.call(window: "24h")
puts "Demo ready: #{monitors.count} monitors, #{SearchRun.count} runs, #{Incident.active.count} open incidents"
puts "24h success rate: #{metrics['success_rate']}% · p95 latency: #{metrics['p95_latency_ms']}ms"
puts "Open http://localhost:3000/dashboard"
