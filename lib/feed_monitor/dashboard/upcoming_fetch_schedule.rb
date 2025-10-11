# frozen_string_literal: true

module FeedMonitor
  module Dashboard
    class UpcomingFetchSchedule
      Group = Struct.new(
        :key,
        :label,
        :min_minutes,
        :max_minutes,
        :window_start,
        :window_end,
        :include_unscheduled,
        :sources,
        keyword_init: true
      ) do
        def empty?
          sources.blank?
        end
      end

      INTERVAL_DEFINITIONS = [
        { key: "0-15", label: "Next 15 minutes", min_minutes: 0, max_minutes: 15 },
        { key: "15-30", label: "15-30 minutes", min_minutes: 15, max_minutes: 30 },
        { key: "30-45", label: "30-45 minutes", min_minutes: 30, max_minutes: 45 },
        { key: "45-60", label: "45-60 minutes", min_minutes: 45, max_minutes: 60 },
        { key: "60-90", label: "60-90 minutes", min_minutes: 60, max_minutes: 90 },
        { key: "90-120", label: "90-120 minutes", min_minutes: 90, max_minutes: 120 },
        { key: "120-150", label: "2-2.5 hours", min_minutes: 120, max_minutes: 150 },
        { key: "150-180", label: "2.5-3 hours", min_minutes: 150, max_minutes: 180 },
        { key: "180-210", label: "3-3.5 hours", min_minutes: 180, max_minutes: 210 },
        { key: "210-240", label: "3.5-4 hours", min_minutes: 210, max_minutes: 240 },
        { key: "240+", label: "Beyond 4 hours", min_minutes: 240, max_minutes: nil, include_unscheduled: true }
      ].freeze

      attr_reader :scope, :reference_time

      def initialize(scope: FeedMonitor::Source.active, reference_time: Time.current)
        @scope = scope
        @reference_time = reference_time
      end

      def groups
        @groups ||= build_groups
      end

      private

      def build_groups
        definitions = build_definitions
        scheduled_sources.each do |source|
          definition = definition_for(source.next_fetch_at)
          definitions[definition[:key]][:sources] << source if definition
        end

        unscheduled_sources.each do |source|
          definition = definitions.values.find { |value| value[:include_unscheduled] }
          next unless definition

          definition[:sources] << source
        end

        definitions.values.map do |definition|
          Group.new(
            key: definition[:key],
            label: definition[:label],
            min_minutes: definition[:min_minutes],
            max_minutes: definition[:max_minutes],
            window_start: window_start_for(definition[:min_minutes]),
            window_end: window_end_for(definition[:max_minutes]),
            include_unscheduled: definition[:include_unscheduled],
            sources: sort_sources(definition[:sources])
          )
        end
      end

      def build_definitions
        INTERVAL_DEFINITIONS.each_with_object({}) do |definition, memo|
          memo[definition[:key]] = definition.merge(sources: [])
        end
      end

      def scheduled_sources
        scope.where.not(next_fetch_at: nil).order(:next_fetch_at)
      end

      def unscheduled_sources
        scope.where(next_fetch_at: nil).order(:name)
      end

      def definition_for(next_fetch_at)
        minutes = minutes_until(next_fetch_at)

        INTERVAL_DEFINITIONS.find do |definition|
          min = definition[:min_minutes]
          max = definition[:max_minutes]

          minutes >= min && (max.nil? || minutes < max)
        end
      end

      def minutes_until(timestamp)
        return Float::INFINITY if timestamp.blank?

        minutes = (timestamp - reference_time) / 60.0
        return 0 if minutes.negative?

        minutes
      end

      def window_start_for(min_minutes)
        return nil if min_minutes.nil? || min_minutes.infinite?

        reference_time + min_minutes.minutes
      end

      def window_end_for(max_minutes)
        return nil if max_minutes.nil? || max_minutes.infinite?

        reference_time + max_minutes.minutes
      end

      def sort_sources(sources)
        future_cap = reference_time + 100.years

        sources.sort_by do |source|
          [source.next_fetch_at || future_cap, source.name.to_s]
        end
      end
    end
  end
end
