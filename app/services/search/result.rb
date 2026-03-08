module Search
  Result = Data.define(:status, :http_status, :duration_ms, :provider, :engine, :raw, :error_type, :error_message) do
    def success?
      status == "success"
    end
  end
end
