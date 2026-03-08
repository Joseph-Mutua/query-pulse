require "benchmark"

namespace :benchmark do
  desc "Benchmark recursive comparison with 10, 100, and 1,000 organic results"
  task comparison: :environment do
    [10, 100, 1_000].each do |size|
      build = lambda do |offset|
        { "organic_results" => Array.new(size) { |index| { "position" => index + 1, "title" => "Result #{index}",
          "link" => "https://example.com/#{index}", "domain" => "example.com", "score" => index + offset } } }
      end
      previous = build.call(0)
      current = build.call(1)
      elapsed = Benchmark.realtime { Comparison::ResultComparator.call(previous:, current:) }
      puts format("%5d results: %8.2f ms", size, elapsed * 1_000)
    end
  end
end
