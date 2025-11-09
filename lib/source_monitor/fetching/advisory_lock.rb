# frozen_string_literal: true

module SourceMonitor
  module Fetching
    # Wraps Postgres advisory lock usage to provide a small, testable collaborator
    # for coordinating fetch execution across processes.
    class AdvisoryLock
      NotAcquiredError = Class.new(StandardError)

      def initialize(namespace:, key:, connection_pool: ActiveRecord::Base.connection_pool)
        @namespace = namespace
        @key = key
        @connection_pool = connection_pool
      end

      def with_lock
        connection_pool.with_connection do |connection|
          locked = try_lock(connection)
          raise NotAcquiredError, "advisory lock #{namespace}/#{key} busy" unless locked

          begin
            yield
          ensure
            release(connection)
          end
        end
      end

      private

      attr_reader :namespace, :key, :connection_pool

      def try_lock(connection)
        result = connection.exec_query(
          "SELECT pg_try_advisory_lock(#{namespace.to_i}, #{key.to_i})"
        )

        truthy?(result.rows.dig(0, 0))
      end

      def release(connection)
        connection.exec_query(
          "SELECT pg_advisory_unlock(#{namespace.to_i}, #{key.to_i})"
        )
      rescue StandardError
        nil
      end

      def truthy?(value)
        value == true || value.to_s == "t"
      end
    end
  end
end
