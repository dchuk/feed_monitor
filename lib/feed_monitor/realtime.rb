# frozen_string_literal: true

require "feed_monitor/realtime/adapter"
require "feed_monitor/realtime/broadcaster"

module FeedMonitor
  module Realtime
    class << self
      def setup!
        FeedMonitor::Realtime::Adapter.configure!
        FeedMonitor::Realtime::Broadcaster.setup!
      end

      delegate :broadcast_source, :broadcast_item, :broadcast_toast, to: FeedMonitor::Realtime::Broadcaster
    end
  end
end
