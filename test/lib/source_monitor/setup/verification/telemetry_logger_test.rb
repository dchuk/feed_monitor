require "test_helper"
require "tmpdir"

module SourceMonitor
  module Setup
    module Verification
      class TelemetryLoggerTest < ActiveSupport::TestCase
        test "writes json payload" do
          Dir.mktmpdir do |dir|
            path = File.join(dir, "log.jsonl")
            summary = Summary.new([
              Result.new(key: :demo, name: "Demo", status: :ok, details: "fine")
            ])

            TelemetryLogger.new(path: path).log(summary)

            content = File.read(path)
            assert_includes content, "\"overall_status\":\"ok\""
          end
        end
      end
    end
  end
end
