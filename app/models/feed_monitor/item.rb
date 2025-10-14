# frozen_string_literal: true

require "feed_monitor/models/url_normalizable"

module FeedMonitor
  class Item < ApplicationRecord
    include FeedMonitor::Models::UrlNormalizable

    belongs_to :source, class_name: "FeedMonitor::Source", inverse_of: :items, counter_cache: true
    has_one :item_content, class_name: "FeedMonitor::ItemContent", inverse_of: :item, dependent: :destroy, autosave: true
    has_many :scrape_logs, class_name: "FeedMonitor::ScrapeLog", inverse_of: :item, dependent: :destroy

    # Explicit scope for active (non-deleted) items - no default_scope to avoid anti-pattern
    scope :active, -> { where(deleted_at: nil) }
    scope :with_deleted, -> { unscope(where: :deleted_at) }
    scope :only_deleted, -> { where.not(deleted_at: nil) }

    normalizes_urls :url, :canonical_url, :comments_url
    validates_url_format :url, :canonical_url, :comments_url

    validates :source, presence: true
    validates :guid, presence: true, uniqueness: { scope: :source_id, case_sensitive: false }
    validates :content_fingerprint, uniqueness: { scope: :source_id }, allow_blank: true
    validates :url, presence: true

    scope :recent, -> { active.order(Arel.sql("published_at DESC NULLS LAST, created_at DESC")) }
    scope :published, -> { active.where.not(published_at: nil) }
    scope :pending_scrape, -> { active.where(scraped_at: nil) }
    scope :failed_scrape, -> { active.where(scrape_status: "failed") }

    delegate :scraped_html, :scraped_content, to: :item_content, allow_nil: true

    FeedMonitor::ModelExtensions.register(self, :item)

    class << self
      def ransackable_attributes(_auth_object = nil)
        %w[title summary url published_at created_at scrape_status]
      end

      def ransackable_associations(_auth_object = nil)
        %w[source]
      end
    end

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
