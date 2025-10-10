# frozen_string_literal: true

module FeedMonitor
  class FetchLog < ApplicationRecord
    belongs_to :source, class_name: "FeedMonitor::Source", inverse_of: :fetch_logs

    attribute :items_created, :integer, default: 0
    attribute :items_updated, :integer, default: 0
    attribute :items_failed, :integer, default: 0
    attribute :http_response_headers, default: -> { {} }
    attribute :metadata, default: -> { {} }

    validates :source, presence: true
    validates :started_at, presence: true
    validates :items_created, :items_updated, :items_failed,
              numericality: { greater_than_or_equal_to: 0 }
    validates :duration_ms, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

    scope :recent, -> { order(started_at: :desc) }
    scope :successful, -> { where(success: true) }
    scope :failed, -> { where(success: false) }
    scope :for_job, ->(job_id) { where(job_id:) }

    FeedMonitor::ModelExtensions.register(self, :fetch_log)
  end
end
