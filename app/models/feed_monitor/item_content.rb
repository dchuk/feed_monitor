# frozen_string_literal: true

module FeedMonitor
  class ItemContent < ApplicationRecord
    self.table_name = "feed_monitor_item_contents"

    belongs_to :item, class_name: "FeedMonitor::Item", inverse_of: :item_content, touch: true

    validates :item, presence: true
  end
end
