# frozen_string_literal: true

require "test_helper"
require "feed_monitor/fetching/advisory_lock"

module FeedMonitor
  module Fetching
    class AdvisoryLockTest < ActiveSupport::TestCase
      LOCK_NAMESPACE = 9_812_345

      class TestError < StandardError; end

      test "yields when the advisory lock is acquired and releases afterwards" do
        key = next_lock_key
        lock = FeedMonitor::Fetching::AdvisoryLock.new(namespace: LOCK_NAMESPACE, key:)

        executed = false
        lock.with_lock do
          executed = true
        end

        assert executed, "expected block to run"
        assert lock_available?(LOCK_NAMESPACE, key), "expected lock to be released after yielding"
      end

      test "raises not acquired error when lock is already held" do
        key = next_lock_key
        lock = FeedMonitor::Fetching::AdvisoryLock.new(namespace: LOCK_NAMESPACE, key:)

        fake_connection = Class.new do
          def exec_query(sql)
            if sql.include?("pg_try_advisory_lock")
              ActiveRecord::Result.new([], [[false]])
            else
              ActiveRecord::Result.new([], [[true]])
            end
          end
        end.new

        ActiveRecord::Base.connection_pool.stub :with_connection, ->(&block) { block.call(fake_connection) } do
          assert_raises(FeedMonitor::Fetching::AdvisoryLock::NotAcquiredError) do
            lock.with_lock { flunk "should not yield when lock is busy" }
          end
        end
      end

      test "releases lock when block raises" do
        key = next_lock_key
        lock = FeedMonitor::Fetching::AdvisoryLock.new(namespace: LOCK_NAMESPACE, key:)

        assert_raises(TestError) do
          lock.with_lock { raise TestError, "boom" }
        end

        assert lock_available?(LOCK_NAMESPACE, key), "expected lock to be released when block raises"
      end

      private

      def next_lock_key
        @next_lock_key ||= 0
        @next_lock_key += 1
      end

      def lock_available?(namespace, key)
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          result = connection.exec_query("SELECT pg_try_advisory_lock(#{namespace}, #{key})")
          value = result.rows.dig(0, 0)
          # Ensure any test lock does not linger.
          connection.exec_query("SELECT pg_advisory_unlock(#{namespace}, #{key})") if truthy?(value)
          truthy?(value)
        end
      end

      def truthy?(value)
        value == true || value.to_s == "t"
      end
    end
  end
end
