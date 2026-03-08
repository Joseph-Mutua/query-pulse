require "rails_helper"

RSpec.describe Assertions::RelevanceScorer do
  it "produces an explainable deterministic score from zero to one hundred" do
    data = { "organic_results" => [{ "domain" => "github.com", "title" => "Ruby scraper", "snippet" => "Web scraping with Ruby" }] }
    assertions = { "required_domains" => ["github.com"], "title_contains" => ["ruby"] }
    first = described_class.call(data:, query: "ruby web scraper", assertions:)
    second = described_class.call(data:, query: "ruby web scraper", assertions:)

    expect(first).to eq(second)
    expect(first["score"]).to be_between(0, 100)
    expect(first["components"].keys).to contain_exactly("query_coverage", "expected_domains", "title_expectations", "snippet_expectations", "assertion_health")
  end
end
