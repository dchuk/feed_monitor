# frozen_string_literal: true

module FeedMonitor
  class ItemContent < ApplicationRecord
    belongs_to :item, class_name: "FeedMonitor::Item", inverse_of: :item_content, touch: true

    validates :item, presence: true

    FeedMonitor::ModelExtensions.register(self, :item_content)
  end
end
