module Reports
  module Middleware
    class StatusCheck < Faraday::Middleware
      attr_reader :app

      def initialize(app)
        super(app)
      end

      VALID_STATUS_CODES = [200, 201, 204, 302, 304, 401, 403, 404, 422]

      def call(env)
        response = app.call(env)
        response.on_complete do |env|
          unless VALID_STATUS_CODES.include?(env.status)
            raise RequestFailure, JSON.parse(env.body)['message']
          end
        end
      end
    end
  end
end
