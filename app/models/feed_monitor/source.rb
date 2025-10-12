# frozen_string_literal: true

require "uri"

module FeedMonitor
  class Source < ApplicationRecord
    FETCH_STATUS_VALUES = %w[idle queued fetching failed].freeze

    has_many :all_items, class_name: "FeedMonitor::Item", inverse_of: :source, dependent: :destroy
    has_many :items, -> { where(deleted_at: nil) }, class_name: "FeedMonitor::Item", inverse_of: :source
    has_many :fetch_logs, class_name: "FeedMonitor::FetchLog", inverse_of: :source, dependent: :destroy
    has_many :scrape_logs, class_name: "FeedMonitor::ScrapeLog", inverse_of: :source, dependent: :destroy

    # Scopes for common source states
    scope :active, -> { where(active: true) }
    scope :due_for_fetch, lambda {
      now = Time.current
      active.where(arel_table[:next_fetch_at].eq(nil).or(arel_table[:next_fetch_at].lteq(now)))
    }
    scope :failed, lambda {
      failure = arel_table[:failure_count].gt(0)
      error_present = arel_table[:last_error].not_eq(nil)
      error_time_present = arel_table[:last_error_at].not_eq(nil)
      where(failure.or(error_present).or(error_time_present))
    }
    scope :healthy, -> { active.where(failure_count: 0, last_error: nil, last_error_at: nil) }

    before_validation :sanitize_user_inputs
    before_validation :normalize_feed_url
    before_validation :normalize_website_url
    after_initialize :ensure_hash_defaults, if: :new_record?
    after_initialize :ensure_fetch_status_default
    after_initialize :ensure_health_defaults

    validates :name, presence: true
    validates :feed_url, presence: true, uniqueness: { case_sensitive: false }
    validates :fetch_interval_minutes, numericality: { greater_than: 0 }
    validates :scraper_adapter, presence: true
    validates :items_retention_days, numericality: { allow_nil: true, only_integer: true, greater_than_or_equal_to: 0 }
    validates :max_items, numericality: { allow_nil: true, only_integer: true, greater_than_or_equal_to: 0 }
    validates :fetch_status, inclusion: { in: FETCH_STATUS_VALUES }
    validates :fetch_retry_attempt, numericality: { greater_than_or_equal_to: 0, only_integer: true }

    validate :feed_url_must_be_http_or_https
    validate :website_url_must_be_http_or_https
    validate :health_auto_pause_threshold_within_bounds

    FeedMonitor::ModelExtensions.register(self, :source)

    class << self
      def ransackable_attributes(_auth_object = nil)
        %w[name feed_url website_url created_at fetch_interval_minutes]
      end

      def ransackable_associations(_auth_object = nil)
        []
      end
    end

    def fetch_interval_minutes=(value)
      self[:fetch_interval_minutes] = value.presence && value.to_i
    end

    def fetch_interval_hours=(value)
      self.fetch_interval_minutes = (value.to_f * 60).round if value.present?
    end

    def fetch_interval_hours
      return 0 unless fetch_interval_minutes

      fetch_interval_minutes.to_f / 60.0
    end

    def fetch_circuit_open?
      fetch_circuit_until.present? && fetch_circuit_until.future?
    end

    def fetch_retry_attempt
      value = super
      value.present? ? value : 0
    end

    def auto_paused?
      auto_paused_until.present? && auto_paused_until.future?
    end

    private

    def ensure_hash_defaults
      self.scrape_settings ||= {}
      self.custom_headers ||= {}
      self.metadata ||= {}
    end

    def ensure_fetch_status_default
      self.fetch_status = "idle" if fetch_status.blank?
    end

    def ensure_health_defaults
      self.health_status = "healthy" if health_status.blank?
    end

    def normalize_feed_url
      @invalid_feed_url = false
      return if feed_url.blank?

      self.feed_url = normalize_url(feed_url)
    rescue URI::InvalidURIError
      @invalid_feed_url = true
    end

    def normalize_website_url
      @invalid_website_url = false
      return if website_url.blank?

      self.website_url = normalize_url(website_url)
    rescue URI::InvalidURIError
      @invalid_website_url = true
    end

    def feed_url_must_be_http_or_https
      return if feed_url.blank?
      errors.add(:feed_url, "must be a valid HTTP(S) URL") if @invalid_feed_url
    end

    def website_url_must_be_http_or_https
      return if website_url.blank?

      errors.add(:website_url, "must be a valid HTTP(S) URL") if @invalid_website_url
    end

    def normalize_url(value)
      uri = URI.parse(value.strip)

      raise URI::InvalidURIError if uri.scheme.blank? || uri.host.blank?

      scheme = uri.scheme.downcase
      unless %w[http https].include?(scheme)
        raise URI::InvalidURIError
      end

      uri.scheme = scheme
      uri.host = uri.host.downcase
      uri.path = "/" if uri.path.blank?
      uri.fragment = nil

      uri.to_s
    end

    def health_auto_pause_threshold_within_bounds
      return if health_auto_pause_threshold.nil?

      value = health_auto_pause_threshold.to_f
      return if value >= 0 && value <= 1

      errors.add(:health_auto_pause_threshold, "must be between 0 and 1")
    end

    def sanitize_user_inputs
      sanitizer = FeedMonitor::Security::ParameterSanitizer

      %i[name feed_url website_url scraper_adapter].each do |attribute|
        value = self[attribute]
        next unless value.is_a?(String)

        sanitized_value = sanitizer.sanitize(value)
        self[attribute] = sanitized_value
      end

      self.scrape_settings = sanitize_hash_attribute(scrape_settings)
      self.custom_headers = sanitize_hash_attribute(custom_headers)
      self.metadata = sanitize_hash_attribute(metadata)
    end

    def sanitize_hash_attribute(value)
      sanitized = FeedMonitor::Security::ParameterSanitizer.sanitize(value || {})
      return {} unless sanitized.is_a?(Hash)

      sanitized
    end
  end
end
