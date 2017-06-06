require 'logger'

module Reports
  module Middleware
    class Logging < Faraday::Middleware
      attr_reader :logger, :app

      def initialize(app)
        super(app)
        level = ENV["LOG_LEVEL"]
        @logger = Logger.new(STDOUT)
        @logger.formatter = proc { |serverity, time, progname, msg| msg + "\n" }
        @logger.level = Logger.const_get(level) if level
      end

      def call(env)
        start_time = Time.now
        response = app.call(env)
        response.on_complete do |response_env|
          duration = Time.now - start_time
          url = env.url.to_s
          method = env.method
          status = response_env.status
          cached = response_env.response_headers['X-Faraday-Cache-Status'] ? 'hit' : 'miss'

          logger.debug '-> %s %s %d (%.3f s) %s' % [url, method, status, duration, cached]
        end
      end
    end
  end
end
