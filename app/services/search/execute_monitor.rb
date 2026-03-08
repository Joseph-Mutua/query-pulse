module Search
  class ExecuteMonitor
    def self.call(monitor:, adapter: nil, search_run: nil, idempotency_key: nil)
      new(monitor:, adapter:, search_run:, idempotency_key:).call
    end

    def initialize(monitor:, adapter:, search_run:, idempotency_key:)
      @monitor = monitor
      @adapter = adapter || AdapterFactory.for(monitor.engine)
      @search_run = search_run
      @idempotency_key = idempotency_key
    end

    def call
      run = @search_run || create_run
      return run if run.status != "pending"

      run.set(status: "running", started_at: Time.current)
      result = @adapter.execute(query: @monitor.query, location: @monitor.location,
                                language: @monitor.language, device: @monitor.device, country: @monitor.country)
      result.success? ? complete_success(run, result) : complete_failure(run, result)
      run.reload
    rescue Mongo::Error::OperationFailure => error
      raise unless error.message.include?("E11000")

      SearchRun.where(idempotency_key: @idempotency_key).first
    rescue StandardError => error
      fail_unexpectedly(run, error)
      raise
    ensure
      if @monitor.persisted? && @monitor.enabled? && (@monitor.next_execution_at.nil? || @monitor.next_execution_at <= Time.current)
        @monitor.schedule_next!
      end
    end

    private

    def create_run
      @monitor.search_runs.create!(status: "pending", engine: @monitor.engine,
                                   provider: @adapter.class.name.demodulize.delete_suffix("Adapter").underscore,
                                   idempotency_key: @idempotency_key)
    end

    def complete_success(run, result)
      normalized = Normalization::SearchResultNormalizer.call(raw: result.raw, monitor: @monitor,
                                                               response_time_ms: result.duration_ms)
      previous = @monitor.snapshots.recent_first.first
      completed_at = Time.current
      run.set(status: "success", completed_at:, http_status: result.http_status,
              response_time_ms: result.duration_ms, result_count: normalized["organic_results"].length,
              provider: result.provider, raw_response: result.raw, normalized_response: normalized)
      current = Comparison::SnapshotBuilder.call(monitor: @monitor, search_run: run, normalized_data: normalized)
      comparison = previous ? Comparison::ResultComparator.call(previous:, current:) : { "changes" => [], "summary" => {} }
      assertion_results = Assertions::Evaluator.call(data: normalized, assertions: @monitor.assertions,
                                                     response_time_ms: result.duration_ms)
      relevance = Assertions::RelevanceScorer.call(data: normalized, query: @monitor.query,
                                                    assertions: @monitor.assertions, assertion_results:)
      run.set(schema_fingerprint: current.schema_hash, changes: comparison["changes"],
              assertion_results:, relevance_score: relevance["score"],
              diagnostics: { "relevance" => relevance, "comparison_summary" => comparison["summary"] })
      performance = Metrics::LatencyRegression.call(monitor: @monitor)
      Incidents::Detector.call(monitor: @monitor, search_run: run, previous:, current:,
                               comparison:, assertion_results:, performance_metrics: performance)
      log_completion(run)
    end

    def complete_failure(run, result)
      run.set(status: result.status, completed_at: Time.current, http_status: result.http_status,
              response_time_ms: result.duration_ms, provider: result.provider,
              error_type: result.error_type, error_message: result.error_message.to_s.truncate(500))
      Incidents::Detector.call(monitor: @monitor, search_run: run)
      log_completion(run, level: :warn)
    end

    def fail_unexpectedly(run, error)
      return unless run&.persisted?

      run.set(status: "failed", completed_at: Time.current, error_type: "UNKNOWN_ERROR",
              error_message: "Unexpected execution failure: #{error.class.name}")
      Observability::EventLogger.log("search_run.failed", log_payload(run).merge(error_class: error.class.name), level: :error)
    end

    def log_completion(run, level: :info)
      Observability::EventLogger.log("search_run.completed", log_payload(run), level:)
    end

    def log_payload(run)
      { request_id: Current.request_id, monitor_id: @monitor.id.to_s, search_run_id: run.id.to_s,
        engine: run.engine, provider: run.provider, duration_ms: run.duration_ms,
        result_count: run.result_count, status: run.status }
    end
  end
end
