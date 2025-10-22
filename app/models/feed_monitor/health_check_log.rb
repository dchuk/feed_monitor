# frozen_string_literal: true

module FeedMonitor
  class HealthCheckLog < ApplicationRecord
    include FeedMonitor::Loggable

    belongs_to :source, class_name: "FeedMonitor::Source", inverse_of: :health_check_logs
    has_one :log_entry,
            as: :loggable,
            class_name: "FeedMonitor::LogEntry",
            inverse_of: :loggable,
            dependent: :destroy

    attribute :http_response_headers, default: -> { {} }

    validates :source, presence: true

    FeedMonitor::ModelExtensions.register(self, :health_check_log)

    after_save :sync_log_entry

    private

    def sync_log_entry
      FeedMonitor::Logs::EntrySync.call(self)
    end
  end
end
