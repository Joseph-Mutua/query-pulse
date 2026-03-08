class RequestSizeLimiter
  MAX_BYTES = 1_048_576

  def initialize(app)
    @app = app
  end

  def call(environment)
    request = Rack::Request.new(environment)
    return @app.call(environment) unless guarded_path?(request.path)
    return @app.call(environment) if request.content_length.to_i <= MAX_BYTES

    body = { error: { code: "PAYLOAD_TOO_LARGE", message: "Request body exceeds 1 MB", details: {} } }.to_json
    [413, { "content-type" => "application/json", "content-length" => body.bytesize.to_s }, [body]]
  end

  private

  def guarded_path?(path)
    path.start_with?("/api/") || path == "/playground"
  end
end
