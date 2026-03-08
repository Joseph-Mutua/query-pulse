require "rails_helper"

RSpec.describe Comparison::SchemaExtractor do
  it "extracts deterministic nested object and array schemas" do
    input = { "items" => [{ "rating" => 4.5, "title" => "Ruby" }, { "title" => "Rails", "rating" => 5.0 }], "count" => 2 }

    expect(described_class.call(input)).to eq(
      "count" => "integer",
      "items" => { "type" => "array", "items" => { "rating" => "float", "title" => "string" } }
    )
  end

  it "hashes structures independently from hash insertion order" do
    first = { "title" => "string", "price" => "integer" }
    second = { "price" => "integer", "title" => "string" }

    expect(Comparison::CanonicalJson.hash(first)).to eq(Comparison::CanonicalJson.hash(second))
  end
end
