module Observability
  module EventLogger
    module_function

    FILTERED_KEYS = /api[_-]?key|authorization|token|secret/i

    def log(event, payload = {}, level: :info)
      safe = sanitize(payload).merge(event:, timestamp: Time.current.iso8601(3))
      Rails.logger.public_send(level, safe.to_json)
    end

    def sanitize(value)
      case value
      when Hash
        value.to_h.transform_keys(&:to_s).to_h do |key, item|
          [key, key.match?(FILTERED_KEYS) ? "[FILTERED]" : sanitize(item)]
        end
      when Array then value.map { |item| sanitize(item) }
      else value
      end
    end
  end
end
