# frozen_string_literal: true

module FeedMonitor
  module Dashboard
    QuickAction = Struct.new(:label, :description, :route_name, keyword_init: true)
  end
end
