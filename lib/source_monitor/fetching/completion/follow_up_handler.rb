# frozen_string_literal: true

module SourceMonitor
  module Fetching
    module Completion
      # Enqueues follow-up scraping work for items created during a fetch.
      class FollowUpHandler
        def initialize(enqueuer_class: SourceMonitor::Scraping::Enqueuer, job_class: SourceMonitor::ScrapeItemJob)
          @enqueuer_class = enqueuer_class
          @job_class = job_class
        end

        def call(source:, result:)
          return unless should_enqueue?(source:, result:)

          Array(result.item_processing&.created_items).each do |item|
            next unless item.present? && item.scraped_at.nil?

            enqueuer_class.enqueue(item:, source:, job_class:, reason: :auto)
          end
        end

        private

        attr_reader :enqueuer_class, :job_class

        def should_enqueue?(source:, result:)
          return false unless result
          return false unless result.status == :fetched
          return false unless source.scraping_enabled? && source.auto_scrape?

          result.item_processing&.created.to_i.positive?
        end
      end
    end
  end
end
