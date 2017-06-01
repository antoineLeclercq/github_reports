require 'time'

module Reports
  module Middleware
    class Cache < Faraday::Middleware
      attr_reader :storage, :app

      def initialize(app, storage)
        super(app)
        @storage = storage
      end

      def call(env)
        url = env.url.to_s
        cached_response = storage.read(url)

        if cached_response
          if !needs_revalidation?(cached_response) && fresh?(cached_response)
            return cached_response
          else
            env.request_headers['If-None-Match'] = cached_response.headers['ETag']
          end
        end

        response = app.call(env)
        response.on_complete do |env|
          if cachable_response?(env)
            if response.status == 304
              cached_response.headers['Date'] = response.headers['Date']
              storage.write(url, cached_response)

              response.env.update(cached_response.env)
            else
              storage.write(url, response)
            end
          end
        end

        response
      end

      private

      def needs_revalidation?(cached_response)
        cached_response.headers['Cache-Control'].include?('must-revalidate') || cached_response.headers['Cache-Control'].include?('no-cache')
      end

      def cachable_response?(response)
        cache_header = response.response_headers['Cache-Control']
        response.method == :get && cache_header && !cache_header.include?('no-store')
      end

      def fresh?(cached_response)
        max_age = response_max_age(cached_response)
        age = response_age(cached_response)
        age <= max_age if max_age && age
      end

      def response_age(cached_response)
        date = cached_response.headers['Date']
        time = Time.httpdate(date) if date
        (Time.now - time).floor if time
      end

      def response_max_age(cached_response)
        return nil unless cached_response.headers['Cache-Control'].include?('max-age')
        match = cached_response.headers['Cache-Control'].match(/max\-age\=(\d+)/)
        match[1].to_i if match[1]
      end
    end
  end
end
