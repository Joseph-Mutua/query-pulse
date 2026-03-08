module Search
  class Error < StandardError
    attr_reader :type, :http_status

    def initialize(message, type: "UNKNOWN_ERROR", http_status: nil)
      super(message)
      @type = type
      @http_status = http_status
    end
  end

  class AuthenticationError < Error
    def initialize(message = "Search provider authentication failed")
      super(message, type: "AUTHENTICATION_ERROR", http_status: 401)
    end
  end
end
