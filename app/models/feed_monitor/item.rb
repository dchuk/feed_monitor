# frozen_string_literal: true

require "uri"

module FeedMonitor
  class Item < ApplicationRecord
    belongs_to :source, class_name: "FeedMonitor::Source", inverse_of: :items, counter_cache: true
    has_one :item_content, class_name: "FeedMonitor::ItemContent", inverse_of: :item, dependent: :destroy, autosave: true
    has_many :scrape_logs, class_name: "FeedMonitor::ScrapeLog", inverse_of: :item, dependent: :destroy

    default_scope { where(deleted_at: nil) }
    scope :with_deleted, -> { unscope(where: :deleted_at) }
    scope :only_deleted, -> { with_deleted.where.not(deleted_at: nil) }

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

    delegate :scraped_html, :scraped_content, to: :item_content, allow_nil: true

    FeedMonitor::ModelExtensions.register(self, :item)

    def scraped_html=(value)
      assign_content_attribute(:scraped_html, value)
    end

    def scraped_content=(value)
      assign_content_attribute(:scraped_content, value)
    end

    def deleted?
      deleted_at.present?
    end

    def soft_delete!(timestamp: Time.current)
      return if deleted?

      self.class.transaction do
        timestamp = timestamp.in_time_zone if timestamp.respond_to?(:in_time_zone)
        timestamp ||= Time.current

        update_columns(
          deleted_at: timestamp,
          updated_at: timestamp
        )

        FeedMonitor::Source.decrement_counter(:items_count, source_id) if source_id
      end
    end

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

    def assign_content_attribute(attribute, value)
      unless item_content
        return if value.nil?

        build_item_content
      end

      item_content.public_send("#{attribute}=", value)

      prune_empty_content_record if item_content.scraped_html.blank? && item_content.scraped_content.blank?
    end

    def prune_empty_content_record
      if item_content.persisted?
        item_content.mark_for_destruction
      else
        association(:item_content).reset
      end
    end
  end
end
