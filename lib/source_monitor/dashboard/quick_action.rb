# frozen_string_literal: true

module SourceMonitor
  module Dashboard
    QuickAction = Struct.new(:label, :description, :route_name, keyword_init: true)
  end
end
