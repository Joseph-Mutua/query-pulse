module Search
  class AuthenticationError < Error
    def initialize(message = "Search provider authentication failed")
      super(message, type: "AUTHENTICATION_ERROR", http_status: 401)
    end
  end
end
