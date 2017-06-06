require 'json'

module Reports
  module Middleware
    class JSONParsing < Faraday::Middleware
      attr_reader :app

      def initialize(app)
        super(app)
      end

      def call(env)
        response = app.call(env)
        response.on_complete do |env|
          content_type_header = env[:response_headers]['Content-Type']
          if content_type_header && content_type_header.include?('application/json')
            parse_json(env)
          end
        end
      end

      def parse_json(env)
        env[:raw_body] = env[:body]
        env[:body] = JSON.parse(env[:body]) unless env[:body].empty?
      end
    end
  end
end
