module Search
  class GoogleAdapter < BaseAdapter
    ENDPOINT = "https://serpapi.com/search.json"

    def initialize(api_key: ENV["SEARCH_API_KEY"], connection: nil)
      @api_key = api_key
      @connection = connection || build_connection
    end

    def execute(query:, location:, language:, device:, country: nil)
      return failure(Search::AuthenticationError.new) if @api_key.blank?

      response, duration = timed do
        @connection.get do |request|
          request.params = {
            engine: "google", q: query, location: location, hl: language,
            gl: country, device: device, api_key: @api_key
          }.compact_blank
        end
      end
      return response_result(response, duration) if response.success?

      failure(classify_http_error(response), duration_ms: duration)
    rescue Faraday::TimeoutError
      failure(Error.new("Search provider timed out", type: "TIMEOUT"))
    rescue Faraday::ConnectionFailed
      failure(Error.new("Search provider network error", type: "NETWORK_ERROR"))
    rescue JSON::ParserError
      failure(Error.new("Search provider returned malformed JSON", type: "INVALID_RESPONSE"))
    end

    private

    def build_connection
      Faraday.new(url: ENDPOINT) do |faraday|
        faraday.request :retry, max: 2, interval: 0.2, backoff_factor: 2,
                                exceptions: [Faraday::TimeoutError, Faraday::ConnectionFailed],
                                retry_statuses: [429, 502, 503, 504]
        faraday.options.timeout = 10
        faraday.options.open_timeout = 3
      end
    end

    def response_result(response, duration)
      raw = JSON.parse(response.body)
      raise JSON::ParserError unless raw.is_a?(Hash)

      Result.new(status: "success", http_status: response.status, duration_ms: duration,
                 provider: provider_name, engine: engine, raw: raw, error_type: nil, error_message: nil)
    rescue JSON::ParserError
      failure(Error.new("Search provider returned malformed JSON", type: "INVALID_RESPONSE"), duration_ms: duration)
    end

    def classify_http_error(response)
      case response.status
      when 401, 403 then Search::AuthenticationError.new
      when 429 then Error.new("Search provider rate limit exceeded", type: "RATE_LIMITED", http_status: 429)
      when 400..499 then Error.new("Search provider rejected the request", type: "PROVIDER_ERROR", http_status: response.status)
      else Error.new("Search provider request failed", type: "PROVIDER_ERROR", http_status: response.status)
      end
    end

    def provider_name = "serpapi"
    def engine = "google"
  end
end
