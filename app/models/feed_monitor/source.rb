# frozen_string_literal: true

require "uri"

module FeedMonitor
  class Source < ApplicationRecord
    has_many :items, class_name: "FeedMonitor::Item", inverse_of: :source, dependent: :destroy
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

    before_validation :normalize_feed_url
    before_validation :normalize_website_url
    after_initialize :ensure_hash_defaults, if: :new_record?

    validates :name, presence: true
    validates :feed_url, presence: true, uniqueness: { case_sensitive: false }
    validates :fetch_interval_minutes, numericality: { greater_than: 0 }
    validates :scraper_adapter, presence: true

    validate :feed_url_must_be_http_or_https
    validate :website_url_must_be_http_or_https

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

    private

    def ensure_hash_defaults
      self.scrape_settings ||= {}
      self.custom_headers ||= {}
      self.metadata ||= {}
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
  end
end
