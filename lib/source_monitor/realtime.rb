# frozen_string_literal: true

require "source_monitor/realtime/adapter"
require "source_monitor/realtime/broadcaster"

module SourceMonitor
  module Realtime
    class << self
      def setup!
        SourceMonitor::Realtime::Adapter.configure!
        SourceMonitor::Realtime::Broadcaster.setup!
      end

      delegate :broadcast_source, :broadcast_item, :broadcast_toast, to: SourceMonitor::Realtime::Broadcaster
    end
  end
end
