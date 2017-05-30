require 'logger'

module Reports
  module Middleware
    class Logging < Faraday::Middleware
      attr_reader :logger, :app

      def initialize(app)
        super(app)
        @logger = Logger.new(STDOUT)
        @logger.formatter = proc { |serverity, time, progname, msg| msg + "\n" }
      end

      def call(env)
        start_time = Time.now
        app.call(env).on_complete do
          duration = Time.now - start_time
          url = env.url.to_s
          method = env.method
          status = env.status
          logger.debug '-> %s %s %d (%.3f s)' % [url, method, status, duration]
        end
      end
    end
  end
end
