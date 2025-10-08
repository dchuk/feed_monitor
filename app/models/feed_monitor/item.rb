# frozen_string_literal: true

require "uri"

module FeedMonitor
  class Item < ApplicationRecord
    self.table_name = "feed_monitor_items"

    belongs_to :source, class_name: "FeedMonitor::Source", inverse_of: :items, counter_cache: true

    before_validation :normalize_urls

    validates :source, presence: true
    validates :guid, presence: true, uniqueness: { scope: :source_id, case_sensitive: false }
    validates :content_fingerprint, uniqueness: { scope: :source_id }, allow_blank: true
    validates :url, presence: true

    validate :url_must_be_http
    validate :canonical_url_must_be_http
    validate :comments_url_must_be_http

    scope :recent, -> { order(Arel.sql("published_at DESC NULLS LAST, created_at DESC")) }
    scope :published, -> { where.not(published_at: nil) }
    scope :pending_scrape, -> { where(scraped_at: nil) }
    scope :failed_scrape, -> { where(scrape_status: "failed") }

    private

    URL_FIELDS = %i[url canonical_url comments_url].freeze

    def normalize_urls
      URL_FIELDS.each do |field|
        instance_variable_set("@invalid_#{field}", nil)
        raw_value = read_attribute(field)
        normalized = normalize_url(raw_value)
        write_attribute(field, normalized)
      rescue URI::InvalidURIError
        instance_variable_set("@invalid_#{field}", true)
      end
    end

    def url_must_be_http
      errors.add(:url, "must be a valid HTTP(S) URL") if invalid_url?(:url)
    end

    def canonical_url_must_be_http
      errors.add(:canonical_url, "must be a valid HTTP(S) URL") if invalid_url?(:canonical_url)
    end

    def comments_url_must_be_http
      errors.add(:comments_url, "must be a valid HTTP(S) URL") if invalid_url?(:comments_url)
    end

    def invalid_url?(field)
      instance_variable_get("@invalid_#{field}")
    end

    def normalize_url(value)
      return nil if value.blank?

      uri = URI.parse(value.strip)
      raise URI::InvalidURIError if uri.scheme.blank? || uri.host.blank?

      scheme = uri.scheme.downcase
      raise URI::InvalidURIError unless %w[http https].include?(scheme)

      uri.scheme = scheme
      uri.host = uri.host.downcase
      uri.path = "/" if uri.path.blank?
      uri.fragment = nil

      uri.to_s
    end
  end
end
