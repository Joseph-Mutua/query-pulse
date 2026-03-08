require "rails_helper"

RSpec.describe Comparison::ResultComparator do
  it "detects fields, types, lengths and values recursively" do
    previous = { "item" => { "title" => "A", "price" => 10 }, "tags" => ["ruby"] }
    current = { "item" => { "title" => 12, "rating" => 4.5 }, "tags" => ["ruby", "rails"] }
    changes = described_class.call(previous:, current:)["changes"]

    expect(changes).to include(include("path" => "item.price", "type" => "FIELD_REMOVED"))
    expect(changes).to include(include("path" => "item.rating", "type" => "FIELD_ADDED"))
    expect(changes).to include(include("path" => "item.title", "type" => "TYPE_CHANGED"))
    expect(changes).to include(include("path" => "tags", "type" => "ARRAY_LENGTH_CHANGED"))
  end

  it "ignores configured volatile paths" do
    result = described_class.call(previous: { "meta" => { "id" => 1 } }, current: { "meta" => { "id" => 2 } }, ignored_paths: ["meta.id"])
    expect(result["changes"]).to be_empty
  end

  it "reports only significant canonical-url ranking movement" do
    result = ->(position, url) { { "position" => position, "title" => url, "link" => url, "domain" => "example.com" } }
    previous = { "organic_results" => [result.call(1, "https://example.com/a"), result.call(2, "https://example.com/b")] }
    current = { "organic_results" => [result.call(6, "https://example.com/a?tracking=1"), result.call(1, "https://example.com/b")] }
    changes = described_class.call(previous:, current:, movement_threshold: 3)["changes"]

    expect(changes).to include(include("type" => "RESULT_ORDER_CHANGED", "movement" => 5, "previous_position" => 1, "current_position" => 6))
  end
end
