module Reports
  module Middleware
    class Authentication < Faraday::Middleware
      attr_reader :app, :token

      def initialize(app)
        super(app)
        @token = ENV['GITHUB_TOKEN']
      end

      def call(env)
        env.request_headers['Authorization'] = "token #{token}"
        app.call(env).on_complete do
          if env.status == 401
            raise AuthenticationFailure, "Authentication failed, please set the Github authentication token to a valid Github access token"
          end
        end
      end
    end
  end
end
