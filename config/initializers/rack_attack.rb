class Rack::Attack
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  throttle("api/ip", limit: 300, period: 5.minutes) do |request|
    request.ip if request.path.start_with?("/api/")
  end

  throttle("execution/ip", limit: 20, period: 1.minute) do |request|
    request.ip if request.post? && (request.path.end_with?("/run") || request.path == "/playground")
  end

  self.throttled_responder = lambda do |_request|
    body = { error: { code: "RATE_LIMITED", message: "Too many requests", details: {} } }.to_json
    [429, { "Content-Type" => "application/json", "Retry-After" => "60" }, [body]]
  end
end
