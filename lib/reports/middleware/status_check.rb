module Reports
  module Middleware
    class StatusCheck < Faraday::Middleware
      attr_reader :app

      VALID_STATUS_CODES = [200, 302, 304, 401, 403, 404, 422]

      def call(env)
        app.call(env).on_complete do
          if !VALID_STATUS_CODES.include?(env.status)
            raise RequestFailure, JSON.parse(env.body)['message']
          end
        end
      end
    end
  end
end
