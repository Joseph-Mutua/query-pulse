module Search
  class FakeAdapter < BaseAdapter
    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def execute(query:, location:, language:, device:, country: nil)
      raw, duration = timed { build_response(query, location, language, device, country) }
      Result.new(status: "success", http_status: 200, duration_ms: [duration, 42].max,
                 provider: provider_name, engine: "google", raw: raw,
                 error_type: nil, error_message: nil)
    end

    private

    def build_response(query, location, language, device, country)
      tokens = query.downcase.scan(/[a-z0-9]+/).reject { |token| token.length < 2 }.uniq
      hosts = %w[github.com ruby-doc.org stackoverflow.com rubygems.org dev.to example.com]
      results = hosts.first(6).each_with_index.map do |host, index|
        slug = tokens.first(3).join("-").presence || "search-result"
        {
          "position" => index + 1,
          "title" => "#{tokens.first(3).map(&:capitalize).join(' ')} — #{host}",
          "link" => "https://#{host}/#{slug}/#{index + 1}",
          "displayed_link" => host,
          "snippet" => "A deterministic result about #{query} from #{host}."
        }
      end
      {
        "search_metadata" => { "id" => "fake-#{@clock.call.to_i}", "status" => "Success" },
        "search_parameters" => { "q" => query, "location" => location, "hl" => language,
                                 "device" => device, "gl" => country },
        "organic_results" => results,
        "related_questions" => ["What is #{tokens.first || 'search'}?"],
        "related_searches" => tokens.first(3).map { |token| { "query" => "#{token} guide" } }
      }
    end

    def provider_name = "fake"
  end
end
