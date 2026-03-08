require "rails_helper"

RSpec.describe Search::GoogleAdapter do
  it "normalizes a successful HTTP response without leaking transport details" do
    stub_request(:get, "https://serpapi.com/search.json").with(query: hash_including("api_key" => "test-key", "q" => "ruby"))
      .to_return(status: 200, body: { organic_results: [{ title: "Ruby" }] }.to_json)
    result = described_class.new(api_key: "test-key").execute(query: "ruby", location: "Austin", language: "en", device: "desktop")

    expect(result).to be_success
    expect(result.http_status).to eq(200)
    expect(result.raw["organic_results"].first["title"]).to eq("Ruby")
  end

  it "does not make a request when credentials are absent" do
    result = described_class.new(api_key: nil).execute(query: "ruby", location: nil, language: "en", device: "desktop")
    expect(result).not_to be_success
    expect(result.error_type).to eq("AUTHENTICATION_ERROR")
    expect(a_request(:any, /serpapi/)).not_to have_been_made
  end
end
