# frozen_string_literal: true

module FeedMonitor
  class ScrapeLog < ApplicationRecord
    belongs_to :item, class_name: "FeedMonitor::Item", inverse_of: :scrape_logs
    belongs_to :source, class_name: "FeedMonitor::Source", inverse_of: :scrape_logs

    attribute :metadata, default: -> { {} }

    validates :item, :source, presence: true
    validates :started_at, presence: true
    validates :duration_ms, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validates :content_length, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validate :source_matches_item

    scope :recent, -> { order(started_at: :desc) }
    scope :successful, -> { where(success: true) }
    scope :failed, -> { where(success: false) }

    FeedMonitor::ModelExtensions.register(self, :scrape_log)

    private

    def source_matches_item
      return if item.nil? || source.nil?

      errors.add(:source, "must match item source") if item.source_id != source_id
    end
  end
end
