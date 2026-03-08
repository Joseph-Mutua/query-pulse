require "rails_helper"

RSpec.describe "search page parsers" do
  def fixture(name)
    Rails.root.join("spec/fixtures/search_pages/#{name}.html").read
  end

  it "extracts organic results and related questions" do
    results = Parsers::SearchPage::OrganicResultsParser.call(fixture("standard"))
    questions = Parsers::SearchPage::RelatedQuestionsParser.call(fixture("standard"))
    expect(results.first).to include("position" => 1, "title" => "Ruby Documentation", "displayed_url" => "ruby-lang.org")
    expect(results.second["url"]).to eq("https://github.com/ruby/ruby")
    expect(questions).to eq(["What is Ruby used for?", "Is Ruby easy to learn?"])
  end

  it "handles missing snippets, changed markup and empty pages" do
    expect(Parsers::SearchPage::OrganicResultsParser.call(fixture("missing_snippet")).first).not_to have_key("snippet")
    expect(Parsers::SearchPage::OrganicResultsParser.call(fixture("changed_markup")).first).to include("position" => 4)
    expect(Parsers::SearchPage::OrganicResultsParser.call(fixture("empty_results"))).to eq([])
  end
end
