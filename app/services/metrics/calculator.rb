module Metrics
  class Calculator
    WINDOWS = { "1h" => 1.hour, "24h" => 24.hours, "7d" => 7.days }.freeze

    def self.call(window: "24h", monitor: nil, now: Time.current)
      new(window:, monitor:, now:).call
    end

    def initialize(window:, monitor:, now:)
      @window = WINDOWS.fetch(window) { raise ArgumentError, "Unsupported metrics window" }
      @window_name = window
      @monitor = monitor
      @now = now
    end

    def call
      runs = scoped_runs.to_a
      latencies = runs.filter_map(&:duration_ms).sort
      counts = runs.filter_map(&:result_count)
      successes = runs.count { |run| run.status == "success" }
      {
        "window" => @window_name,
        "from" => (@now - @window).iso8601,
        "to" => @now.iso8601,
        "request_count" => runs.length,
        "success_count" => successes,
        "failure_count" => runs.length - successes,
        "success_rate" => percentage(successes, runs.length),
        "failure_rate" => percentage(runs.length - successes, runs.length),
        "average_latency_ms" => average(latencies),
        "p50_latency_ms" => percentile(latencies, 0.50),
        "p95_latency_ms" => percentile(latencies, 0.95),
        "p99_latency_ms" => percentile(latencies, 0.99),
        "average_result_count" => average(counts),
        "schema_changes" => runs.count { |run| Array(run.response_changes).any? { |change| %w[FIELD_ADDED FIELD_REMOVED TYPE_CHANGED].include?(change["type"]) } },
        "incident_count" => scoped_incidents.count
      }
    end

    private

    def scoped_runs
      criteria = SearchRun.where(:started_at.gte => @now - @window, :started_at.lte => @now)
      @monitor ? criteria.where(monitor_id: @monitor.id) : criteria
    end

    def scoped_incidents
      criteria = Incident.where(:first_seen_at.gte => @now - @window, :first_seen_at.lte => @now)
      @monitor ? criteria.where(monitor_id: @monitor.id) : criteria
    end

    def average(values)
      return 0 if values.empty?

      (values.sum.fdiv(values.length)).round(2)
    end

    def percentile(values, quantile)
      return 0 if values.empty?

      values[((values.length - 1) * quantile).ceil]
    end

    def percentage(numerator, denominator)
      return 0.0 if denominator.zero?

      (numerator.fdiv(denominator) * 100).round(2)
    end
  end
end
