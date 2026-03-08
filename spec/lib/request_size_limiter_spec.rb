require "rails_helper"

RSpec.describe RequestSizeLimiter do
  subject(:response) { described_class.new(application).call(environment) }

  let(:application) { ->(_environment) { [204, {}, []] } }
  let(:environment) do
    Rack::MockRequest.env_for(
      "/api/v1/monitors",
      method: :post,
      "CONTENT_LENGTH" => (described_class::MAX_BYTES + 1).to_s
    )
  end

  it "rejects oversized API requests before they reach Rails" do
    status, headers, body = response

    expect(status).to eq(413)
    expect(headers.fetch("content-type")).to eq("application/json")
    expect(JSON.parse(body.join).dig("error", "code")).to eq("PAYLOAD_TOO_LARGE")
  end

  it "does not guard ordinary application pages" do
    environment["PATH_INFO"] = "/dashboard"

    expect(response.first).to eq(204)
  end
end
