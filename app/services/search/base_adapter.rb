module Search
  class BaseAdapter
    def execute(query:, location:, language:, device:, country: nil)
      raise NotImplementedError, "#{self.class.name} must implement #execute"
    end

    private

    def timed
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      value = yield
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      [value, duration_ms]
    end

    def failure(error, duration_ms: nil)
      status = case error.type
      when "TIMEOUT" then "timeout"
      when "INVALID_RESPONSE" then "invalid_response"
      else "failed"
      end
      Result.new(
        status:,
        http_status: error.http_status,
        duration_ms: duration_ms,
        provider: provider_name,
        engine: engine,
        raw: {},
        error_type: error.type,
        error_message: error.message
      )
    end
  end
end
