# frozen_string_literal: true

module Feedmon
  class HealthCheckLog < ApplicationRecord
    include Feedmon::Loggable

    belongs_to :source, class_name: "Feedmon::Source", inverse_of: :health_check_logs
    has_one :log_entry,
            as: :loggable,
            class_name: "Feedmon::LogEntry",
            inverse_of: :loggable,
            dependent: :destroy

    attribute :http_response_headers, default: -> { {} }

    validates :source, presence: true

    Feedmon::ModelExtensions.register(self, :health_check_log)

    after_save :sync_log_entry

    private

    def sync_log_entry
      Feedmon::Logs::EntrySync.call(self)
    end
  end
end
