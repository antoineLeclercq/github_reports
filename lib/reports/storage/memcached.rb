require 'dalli'

module Reports
  module Storage
    class Memcached
      attr_reader :memcached

      def initialize(memcached=Dalli::Client.new)
        @memcached = memcached

        memcached.alive!
      rescue Dalli::RingError => error
        raise Reports::ConfigurationError.new("Could not connect to memecached: #{error.message}")
      end

      def read(key)
        serialized_value = memcached.get(key)
        Marshal.load(serialized_value) if serialized_value
      end

      def write(key, value)
        memcached.set(key, Marshal.dump(value))
      end

      def flush
        memcached.flush
      end
    end
  end
end
