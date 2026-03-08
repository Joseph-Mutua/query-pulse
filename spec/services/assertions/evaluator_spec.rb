require "rails_helper"

RSpec.describe Assertions::Evaluator do
  let(:data) do
    { "organic_results" => [{ "domain" => "github.com", "title" => "Ruby scraper", "snippet" => "Rails parsing guide" }],
      "search_metadata" => { "response_time_ms" => 900 } }
  end

  it "returns detailed results for every supported expectation" do
    results = described_class.call(data:, assertions: {
      minimum_results: 2, required_domains: ["github.com"], forbidden_domains: ["spam.example"],
      title_contains: ["ruby"], snippet_contains: ["parsing"], maximum_response_time_ms: 800,
      required_fields: ["organic_results[].title"]
    })

    expect(results.find { |result| result["assertion"] == "minimum_results" }).to include("passed" => false, "actual" => 1)
    expect(results.find { |result| result["assertion"] == "required_domains" }).to include("passed" => true)
    expect(results.find { |result| result["assertion"] == "maximum_response_time_ms" }).to include("passed" => false, "actual" => 900)
    expect(results.find { |result| result["assertion"] == "required_fields" }).to include("passed" => true)
  end
end
