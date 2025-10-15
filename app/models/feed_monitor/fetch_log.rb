# frozen_string_literal: true

module FeedMonitor
  class FetchLog < ApplicationRecord
    include FeedMonitor::Loggable

    belongs_to :source, class_name: "FeedMonitor::Source", inverse_of: :fetch_logs
    has_one :log_entry, as: :loggable, class_name: "FeedMonitor::LogEntry", inverse_of: :loggable, dependent: :destroy

    attribute :items_created, :integer, default: 0
    attribute :items_updated, :integer, default: 0
    attribute :items_failed, :integer, default: 0
    attribute :http_response_headers, default: -> { {} }

    validates :source, presence: true
    validates :items_created, :items_updated, :items_failed,
              numericality: { greater_than_or_equal_to: 0 }

    scope :for_job, ->(job_id) { where(job_id:) }

    FeedMonitor::ModelExtensions.register(self, :fetch_log)

    after_save :sync_log_entry

    private

    def sync_log_entry
      FeedMonitor::Logs::EntrySync.call(self)
    end
  end
end
