# frozen_string_literal: true

require "feed_monitor/realtime/broadcaster"

module FeedMonitor
  module Realtime
    class << self
      delegate :broadcast_source, :broadcast_item, :broadcast_toast, :setup!, to: FeedMonitor::Realtime::Broadcaster
    end
  end
end

