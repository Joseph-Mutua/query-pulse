module Metrics
  class LatencyRegression
    MINIMUM_SAMPLE_SIZE = 10
    DEFAULT_THRESHOLD = 0.5

    def self.call(monitor:, recent_size: 10, threshold: DEFAULT_THRESHOLD)
      new(monitor:, recent_size:, threshold:).call
    end

    def initialize(monitor:, recent_size:, threshold:)
      @monitor = monitor
      @recent_size = [recent_size.to_i, MINIMUM_SAMPLE_SIZE].max
      @threshold = threshold.to_f
    end

    def call
      values = @monitor.search_runs.successful.recent_first.limit(@recent_size * 6).pluck(:response_time_ms).compact
      recent = values.first(@recent_size)
      historical = values.drop(@recent_size)
      return insufficient(recent.length, historical.length) if recent.length < MINIMUM_SAMPLE_SIZE || historical.length < MINIMUM_SAMPLE_SIZE

      recent_p95 = percentile(recent)
      historical_p95 = percentile(historical)
      increase = historical_p95.zero? ? 0 : (recent_p95 - historical_p95).fdiv(historical_p95)
      {
        "latency_regression" => increase >= @threshold,
        "historical_p95_ms" => historical_p95,
        "recent_p95_ms" => recent_p95,
        "increase_percent" => (increase * 100).round(1),
        "recent_sample_size" => recent.length,
        "historical_sample_size" => historical.length
      }
    end

    private

    def insufficient(recent, historical)
      { "latency_regression" => false, "reason" => "insufficient_samples",
        "minimum_sample_size" => MINIMUM_SAMPLE_SIZE, "recent_sample_size" => recent,
        "historical_sample_size" => historical }
    end

    def percentile(values)
      sorted = values.sort
      sorted[((sorted.length - 1) * 0.95).ceil]
    end
  end
end
