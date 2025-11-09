# frozen_string_literal: true

module Feedmon
  class ScrapeLog < ApplicationRecord
    include Feedmon::Loggable

    belongs_to :item, class_name: "Feedmon::Item", inverse_of: :scrape_logs
    belongs_to :source, class_name: "Feedmon::Source", inverse_of: :scrape_logs
    has_one :log_entry, as: :loggable, class_name: "Feedmon::LogEntry", inverse_of: :loggable, dependent: :destroy

    validates :item, :source, presence: true
    validates :content_length, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validate :source_matches_item

    Feedmon::ModelExtensions.register(self, :scrape_log)

    after_save :sync_log_entry

    private

    def source_matches_item
      return if item.nil? || source.nil?

      errors.add(:source, "must match item source") if item.source_id != source_id
    end

    def sync_log_entry
      Feedmon::Logs::EntrySync.call(self)
    end
  end
end
