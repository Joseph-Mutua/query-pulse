require "uri"

module Normalization
  class SearchResultNormalizer
    def self.call(raw:, monitor:, response_time_ms:)
      new(raw:, monitor:, response_time_ms:).call
    end

    def initialize(raw:, monitor:, response_time_ms:)
      @raw = raw.to_h.deep_stringify_keys
      @monitor = monitor
      @response_time_ms = response_time_ms
    end

    def call
      {
        "search_metadata" => {
          "engine" => @monitor.engine,
          "query" => @monitor.query,
          "location" => @monitor.location,
          "language" => @monitor.language,
          "device" => @monitor.device,
          "response_time_ms" => @response_time_ms
        },
        "organic_results" => normalize_organic_results,
        "related_questions" => normalize_questions,
        "related_searches" => normalize_related_searches,
        "provider_data" => @raw.except("organic_results", "related_questions", "related_searches")
      }
    end

    private

    def normalize_organic_results
      Array(@raw["organic_results"]).each_with_index.filter_map do |result, index|
        next unless result.is_a?(Hash)

        link = result["link"].to_s
        {
          "position" => result["position"] || index + 1,
          "title" => result["title"].to_s,
          "link" => link,
          "displayed_link" => result["displayed_link"].to_s,
          "domain" => safe_domain(link),
          "snippet" => result["snippet"].to_s
        }.compact
      end
    end

    def normalize_questions
      Array(@raw["related_questions"]).filter_map do |item|
        item.is_a?(Hash) ? (item["question"] || item["title"]) : item.to_s.presence
      end
    end

    def normalize_related_searches
      Array(@raw["related_searches"]).filter_map do |item|
        item.is_a?(Hash) ? (item["query"] || item["title"]) : item.to_s.presence
      end
    end

    def safe_domain(link)
      URI.parse(link).host.to_s.downcase.sub(/\Awww\./, "")
    rescue URI::InvalidURIError
      ""
    end
  end
end
