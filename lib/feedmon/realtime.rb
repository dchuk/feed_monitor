# frozen_string_literal: true

require "feedmon/realtime/adapter"
require "feedmon/realtime/broadcaster"

module Feedmon
  module Realtime
    class << self
      def setup!
        Feedmon::Realtime::Adapter.configure!
        Feedmon::Realtime::Broadcaster.setup!
      end

      delegate :broadcast_source, :broadcast_item, :broadcast_toast, to: Feedmon::Realtime::Broadcaster
    end
  end
end
