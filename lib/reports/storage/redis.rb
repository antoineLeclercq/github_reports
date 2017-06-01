require 'redis'

module Reports
  module Storage
    class RedisWrapper
      attr_reader :redis

      def initialize(redis=Redis.new)
        @redis = redis

        redis.ping
      rescue Redis::CannotConnectError => error
        raise Reports::ConfigurationError.new("Could not connect to redis: #{error.message}")
      end

      def read(key)
        serialized_value = redis.get(key)
        Marshal.load(serialized_value) if serialized_value
      end

      def write(key, value)
        redis.set(key, Marshal.dump(value))
      end

      def flush
        redis.flushdb
      end
    end
  end
end
