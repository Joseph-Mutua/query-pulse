require "digest"

module Incidents
  class Detector
    TYPE_MAP = {
      "FIELD_ADDED" => "field_added",
      "FIELD_REMOVED" => "field_removed",
      "TYPE_CHANGED" => "type_changed",
      "ARRAY_LENGTH_CHANGED" => "result_count_changed",
      "RESULT_ORDER_CHANGED" => "result_order_changed"
    }.freeze

    def self.call(monitor:, search_run:, previous: nil, current: nil, comparison: {}, assertion_results: [], performance_metrics: {})
      new(monitor:, search_run:, previous:, current:, comparison:, assertion_results:, performance_metrics:).call
    end

    def initialize(monitor:, search_run:, previous:, current:, comparison:, assertion_results:, performance_metrics:)
      @monitor = monitor
      @search_run = search_run
      @previous = previous
      @current = current
      @comparison = comparison.to_h.deep_stringify_keys
      @assertion_results = assertion_results
      @performance_metrics = performance_metrics.to_h.deep_stringify_keys
      @seen_fingerprints = []
    end

    def call
      detect_request_failure
      detect_empty_results
      detect_comparison_changes
      detect_assertion_failures
      detect_latency_regression
      Resolver.call(monitor: @monitor, seen_fingerprints: @seen_fingerprints)
      @seen_fingerprints
    end

    private

    def detect_request_failure
      return if @search_run.status == "success"

      upsert(type: "request_failure", severity: @search_run.error_type == "AUTHENTICATION_ERROR" ? "critical" : "warning",
             title: "Search request failed", description: @search_run.error_message.presence || "Provider execution failed",
             path: "request", previous: nil, current: @search_run.error_type,
             metadata: { "error_type" => @search_run.error_type, "http_status" => @search_run.http_status })
    end

    def detect_empty_results
      return unless @search_run.status == "success" && @search_run.result_count.to_i.zero?

      upsert(type: "empty_results", severity: "critical", title: "Search returned no organic results",
             description: "A successful provider response contained an empty organic result set.",
             path: "organic_results", previous: previous_result_count, current: 0)
    end

    def detect_comparison_changes
      Array(@comparison["changes"]).each do |change|
        incident_type = TYPE_MAP[change["type"]]
        next unless incident_type
        next if change["type"] == "ARRAY_LENGTH_CHANGED" && change["path"] != "organic_results"

        upsert(type: incident_type, severity: change["severity"],
               title: title_for(change["type"], change["path"]),
               description: "#{change['type'].humanize} at #{change['path']}.", path: change["path"],
               previous: change["previous"], current: change["current"], metadata: change.except("previous", "current"))
      end
    end

    def detect_assertion_failures
      @assertion_results.reject { |result| result["passed"] }.each do |result|
        domain_assertion = %w[required_domains forbidden_domains].include?(result["assertion"])
        type = domain_assertion ? "domain_mismatch" : "assertion_failed"
        upsert(type:, severity: type == "domain_mismatch" ? "critical" : "warning",
               title: "#{result['assertion'].humanize} assertion failed",
               description: "Observed search results did not meet the configured expectation.",
               path: "assertions.#{result['assertion']}", previous: result["expected"], current: result["actual"],
               metadata: result["details"] || {})
      end
    end

    def detect_latency_regression
      return unless @performance_metrics["latency_regression"]

      upsert(type: "latency_regression", severity: "critical", title: "Response latency regressed",
             description: "Recent p95 latency is materially above the historical baseline.",
             path: "performance.p95_latency_ms", previous: @performance_metrics["historical_p95_ms"],
             current: @performance_metrics["recent_p95_ms"], metadata: @performance_metrics)
    end

    def upsert(type:, severity:, title:, description:, path:, previous:, current:, metadata: {})
      fingerprint = Digest::SHA256.hexdigest([@monitor.id.to_s, type, path].join("|"))
      @seen_fingerprints << fingerprint
      incident = @monitor.incidents.active.where(fingerprint:).first
      now = Time.current
      if incident
        incident.inc(occurrence_count: 1)
        incident.set(search_run_id: @search_run.id, last_seen_at: now, current_value: current, metadata: metadata)
      else
        @monitor.incidents.create!(search_run: @search_run, incident_type: type, severity:, title:, description:, path:,
                                   previous_value: previous, current_value: current, first_seen_at: now, last_seen_at: now,
                                   fingerprint:, metadata:)
      end
    end

    def title_for(type, path)
      "#{type.humanize} · #{path.presence || 'response'}"
    end

    def previous_result_count
      @previous&.normalized_data&.fetch("organic_results", [])&.length
    end
  end
end
