# frozen_string_literal: true

module FeedMonitor
  class ScrapeLog < ApplicationRecord
    include FeedMonitor::Loggable

    belongs_to :item, class_name: "FeedMonitor::Item", inverse_of: :scrape_logs
    belongs_to :source, class_name: "FeedMonitor::Source", inverse_of: :scrape_logs

    validates :item, :source, presence: true
    validates :content_length, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validate :source_matches_item

    FeedMonitor::ModelExtensions.register(self, :scrape_log)

    private

    def source_matches_item
      return if item.nil? || source.nil?

      errors.add(:source, "must match item source") if item.source_id != source_id
    end
  end
end
