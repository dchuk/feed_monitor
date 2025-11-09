# frozen_string_literal: true

module Feedmon
  module Logs
    class EntrySync
      def self.call(loggable)
        new(loggable).call
      end

      def initialize(loggable)
        @loggable = loggable
      end

      def call
        return unless loggable&.persisted?
        return unless loggable.respond_to?(:log_entry)

        entry = loggable.log_entry || loggable.build_log_entry
        entry.assign_attributes(entry_attributes)
        entry.save!
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved
        Rails.logger&.error("[Feedmon::Logs::EntrySync] Failed to sync log entry for #{loggable.class.name}##{loggable.id}")
        nil
      end

      private

      attr_reader :loggable

      def entry_attributes
        {
          source: loggable.source,
          item: extract_item,
          success: boolean_success,
          started_at: loggable.started_at,
          completed_at: loggable.respond_to?(:completed_at) ? loggable.completed_at : nil,
          http_status: safe_attribute(:http_status),
          duration_ms: safe_attribute(:duration_ms),
          items_created: safe_attribute(:items_created),
          items_updated: safe_attribute(:items_updated),
          items_failed: safe_attribute(:items_failed),
          scraper_adapter: safe_attribute(:scraper_adapter),
          content_length: safe_attribute(:content_length),
          error_class: safe_attribute(:error_class),
          error_message: safe_attribute(:error_message)
        }
      end

      def extract_item
        return nil unless loggable.respond_to?(:item)

        loggable.item
      end

      def safe_attribute(attribute)
        loggable.respond_to?(attribute) ? loggable.public_send(attribute) : nil
      end

      def boolean_success
        return false unless loggable.respond_to?(:success)

        value = loggable.public_send(:success)
        return false if value.nil?

        ActiveModel::Type::Boolean.new.cast(value)
      end
    end
  end
end
