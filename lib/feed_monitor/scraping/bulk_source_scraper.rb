# frozen_string_literal: true

module FeedMonitor
  module Scraping
    # Orchestrates bulk scrape enqueues for a source based on a user-selected
    # scope. Works alongside the single-item enqueuer to ensure we respect
    # per-source limits and provide actionable feedback for the UI.
    class BulkSourceScraper
      SELECTIONS = %i[current unscraped all].freeze
      SELECTION_LABELS = {
        current: "current view",
        unscraped: "unscraped items",
        all: "all items"
      }.freeze
      DEFAULT_PREVIEW_LIMIT = 10

      Result = Struct.new(
        :status,
        :selection,
        :attempted_count,
        :enqueued_count,
        :already_enqueued_count,
        :failure_count,
        :failure_details,
        :messages,
        :rate_limited,
        keyword_init: true
      ) do
        def success?
          status == :success
        end

        def partial?
          status == :partial
        end

        def error?
          status == :error
        end

        def rate_limited?
          !!rate_limited
        end
      end

      def self.selection_label(selection)
        SELECTION_LABELS[normalize_selection(selection)] || SELECTION_LABELS[:current]
      end

      def self.selection_counts(source:, preview_items:, preview_limit: 10)
        preview_collection = Array(preview_items).compact
        base_scope = FeedMonitor::Item.active.where(source_id: source.id)
        {
          current: preview_collection.size.clamp(0, preview_limit.to_i.nonzero? || preview_collection.size),
          unscraped: base_scope.merge(unscraped_scope).count,
          all: base_scope.count
        }
      end

      def self.normalize_selection(selection)
        value = selection.is_a?(String) ? selection.strip : selection
        value = value.to_s.downcase.to_sym if value
        value if SELECTIONS.include?(value)
      end

      def initialize(source:, selection:, preview_limit: DEFAULT_PREVIEW_LIMIT, enqueuer: FeedMonitor::Scraping::Enqueuer, config: FeedMonitor.config.scraping)
        @source = source
        @selection = self.class.normalize_selection(selection) || :current
        normalized_limit = preview_limit.respond_to?(:to_i) ? preview_limit.to_i : DEFAULT_PREVIEW_LIMIT
        @preview_limit = normalized_limit.positive? ? normalized_limit : DEFAULT_PREVIEW_LIMIT
        @enqueuer = enqueuer
        @config = config
      end

      def call
        return disabled_result unless source.scraping_enabled?
        return invalid_selection_result unless SELECTIONS.include?(selection)

        items = scoped_items.to_a
        attempted_count = items.size

        return no_items_result if attempted_count.zero?

        failure_details = Hash.new(0)
        messages = []
        enqueued_count = 0
        already_enqueued_count = 0
        rate_limited = false

        items.each do |item|
          enqueue_result = enqueuer.enqueue(item: item, source:, reason: :manual)

          case enqueue_result.status
          when :enqueued
            enqueued_count += 1
          when :already_enqueued
            already_enqueued_count += 1
          when :rate_limited
            failure_details[:rate_limited] += 1
            messages << enqueue_result.message if enqueue_result.message.present?
            rate_limited = true
            break
          else
            key = enqueue_result.status || :unknown
            failure_details[key] += 1
            messages << enqueue_result.message if enqueue_result.message.present?
          end
        end

        failure_count = failure_details.values.sum
        status = determine_status(enqueued_count:, failure_count:, already_enqueued_count:)

        Result.new(
          status:,
          selection:,
          attempted_count: attempted_count,
          enqueued_count:,
          already_enqueued_count:,
          failure_count:,
          failure_details: failure_details.freeze,
          messages: messages.compact.uniq,
          rate_limited: rate_limited
        )
      end

      private

      attr_reader :source, :selection, :preview_limit, :enqueuer, :config

      def scoped_items
        scope = case selection
        when :current
          base_scope.limit(preview_limit)
        when :unscraped
          base_scope.merge(unscraped_scope)
        when :all
          base_scope
        else
          base_scope.limit(preview_limit)
        end

        scope = without_inflight(scope)
        apply_batch_limit(scope)
      end

      def base_scope
        FeedMonitor::Item.active.where(source_id: source.id).order(Arel.sql("published_at DESC NULLS LAST, created_at DESC"))
      end

      def without_inflight(scope)
        statuses = FeedMonitor::Scraping::State::IN_FLIGHT_STATUSES
        column = FeedMonitor::Item.arel_table[:scrape_status]
        scope.where(column.eq(nil).or(column.not_in(statuses)))
      end

      def self.unscraped_scope
        item_table = FeedMonitor::Item.arel_table
        failed_statuses = %w[failed partial]
        FeedMonitor::Item.active.where(
          item_table[:scraped_at].eq(nil)
            .or(item_table[:scrape_status].in(failed_statuses))
        )
      end

      def unscraped_scope
        self.class.unscraped_scope
      end

      def apply_batch_limit(scope)
        limit = config.max_bulk_batch_size
        return scope unless limit

        current_limit = scope.limit_value
        effective_limit = current_limit ? [current_limit, limit].min : limit
        scope.limit(effective_limit)
      end

      def determine_status(enqueued_count:, failure_count:, already_enqueued_count:)
        if enqueued_count.positive? && failure_count.zero?
          :success
        elsif enqueued_count.positive?
          :partial
        elsif already_enqueued_count.positive?
          :partial
        else
          :error
        end
      end

      def disabled_result
        Result.new(
          status: :error,
          selection:,
          attempted_count: 0,
          enqueued_count: 0,
          already_enqueued_count: 0,
          failure_count: 1,
          failure_details: { scraping_disabled: 1 },
          messages: ["Scraping is disabled for this source."],
          rate_limited: false
        )
      end

      def invalid_selection_result
        Result.new(
          status: :error,
          selection:,
          attempted_count: 0,
          enqueued_count: 0,
          already_enqueued_count: 0,
          failure_count: 1,
          failure_details: { invalid_selection: 1 },
          messages: ["Invalid selection for bulk scrape."],
          rate_limited: false
        )
      end

      def no_items_result
        Result.new(
          status: :error,
          selection:,
          attempted_count: 0,
          enqueued_count: 0,
          already_enqueued_count: 0,
          failure_count: 1,
          failure_details: { no_items: 1 },
          messages: ["No items match the selected scope."],
          rate_limited: false
        )
      end
    end
  end
end
