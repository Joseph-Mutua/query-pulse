module Search
  class AdapterFactory
    def self.for(engine, provider: ENV.fetch("SEARCH_PROVIDER", nil))
      return FakeAdapter.new if Rails.env.test? || provider == "fake" || engine.to_s == "fake"

      case engine.to_s
      when "google" then GoogleAdapter.new
      else raise ArgumentError, "Unsupported search engine: #{engine}"
      end
    end
  end
end
