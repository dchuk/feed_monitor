# frozen_string_literal: true

require "test_helper"

module Feedmon
  module Jobs
    class CleanupOptionsTest < ActiveSupport::TestCase
      test "normalize returns empty hash when nil" do
        assert_equal({}, Feedmon::Jobs::CleanupOptions.normalize(nil))
      end

      test "normalize symbolises keys" do
        options = Feedmon::Jobs::CleanupOptions.normalize("now" => "2025-10-12 10:00:00")
        assert_equal "2025-10-12 10:00:00", options[:now]
      end

      test "resolve_time parses string with timezone awareness" do
        travel_to Time.zone.local(2025, 10, 12, 12, 0, 0) do
          time = Feedmon::Jobs::CleanupOptions.resolve_time("2025-10-11 09:30:00")
          assert_equal Time.zone.parse("2025-10-11 09:30:00"), time
        end
      end

      test "resolve_time falls back to current time when parsing fails" do
        travel_to Time.zone.local(2025, 10, 12, 12, 0, 0) do
          time = Feedmon::Jobs::CleanupOptions.resolve_time("invalid")
          assert_in_delta Time.current, time, 1.second
        end
      end

      test "extract_ids handles arrays strings and ignores blanks" do
        ids = Feedmon::Jobs::CleanupOptions.extract_ids([ " 1", "2, 3", nil, "a" ])
        assert_equal [ 1, 2, 3 ], ids
      end

      test "integer returns nil when value invalid" do
        assert_nil Feedmon::Jobs::CleanupOptions.integer("abc")
      end

      test "integer returns integer when valid" do
        assert_equal 50, Feedmon::Jobs::CleanupOptions.integer("50")
      end

      test "batch_size returns default when nil or non-positive" do
        assert_equal 100, Feedmon::Jobs::CleanupOptions.batch_size({}, default: 100)
        assert_equal 100, Feedmon::Jobs::CleanupOptions.batch_size({ batch_size: "0" }, default: 100)
      end

      test "batch_size returns value when positive" do
        assert_equal 25, Feedmon::Jobs::CleanupOptions.batch_size({ batch_size: "25" }, default: 100)
      end
    end
  end
end
