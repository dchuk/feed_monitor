# frozen_string_literal: true

module FeedMonitor
  module Analytics
    class SourceActivityRates
      DEFAULT_LOOKBACK = 14.days

      def initialize(scope: FeedMonitor::Source.all, lookback: DEFAULT_LOOKBACK, now: Time.current)
        @scope = scope
        @lookback = lookback
        @now = now
      end

      def per_source_rates
        return {} if source_ids.empty?

        counts = FeedMonitor::Item
          .where(source_id: source_ids)
          .where("created_at >= ?", window_start)
          .group(:source_id)
          .count

        days = [lookback.in_days, 1].max

        counts.transform_values { |count| count.to_f / days }.tap do |results|
          source_ids.each { |source_id| results[source_id] ||= 0.0 }
        end
      end

      private

      attr_reader :scope, :lookback, :now

      def source_ids
        @source_ids ||= if scope.respond_to?(:pluck)
                          scope.pluck(:id)
                        else
                          Array(scope).map { |record| record.respond_to?(:id) ? record.id : record }
                        end
      end

      def window_start
        now - lookback
      end
    end
  end
end
