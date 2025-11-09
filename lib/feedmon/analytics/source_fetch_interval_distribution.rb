# frozen_string_literal: true

module Feedmon
  module Analytics
    class SourceFetchIntervalDistribution
      Bucket = Struct.new(:label, :min, :max, :count, keyword_init: true)

      BUCKETS = [
        { label: "5-30 min", min: 5, max: 30 },
        { label: "30-60 min", min: 30, max: 60 },
        { label: "60-120 min", min: 60, max: 120 },
        { label: "120-240 min", min: 120, max: 240 },
        { label: "240-480 min", min: 240, max: 480 },
        { label: "480+ min", min: 480, max: nil }
      ].freeze

      def initialize(scope: Feedmon::Source.all)
        @scope = scope
      end

      def buckets
        @buckets ||= build_buckets
      end

      private

      attr_reader :scope

      def build_buckets
        values = scope.pluck(:fetch_interval_minutes).compact
        counts = Hash.new(0)

        values.each do |value|
          bucket = bucket_for(value)
          counts[bucket_key(bucket)] += 1
        end

        BUCKETS.map do |definition|
          bucket = definition.merge(count: counts[bucket_key(definition)] || 0)
          Bucket.new(**bucket)
        end
      end

      def bucket_for(value)
        BUCKETS.find do |definition|
          min = definition[:min] || 0
          max = definition[:max]
          value >= min && (max.nil? || value < max)
        end || BUCKETS.first
      end

      def bucket_key(definition)
        [ definition[:min], definition[:max] ]
      end
    end
  end
end
