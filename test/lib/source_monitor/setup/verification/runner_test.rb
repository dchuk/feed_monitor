require "test_helper"

module SourceMonitor
  module Setup
    module Verification
      class RunnerTest < ActiveSupport::TestCase
        test "aggregates verifier results" do
          verifier = -> { Result.new(key: :demo, name: "Demo", status: :ok, details: "Fine") }
          summary = Runner.new(verifiers: [ verifier ]).call

          assert summary.ok?
          assert_equal :ok, summary.overall_status
          assert_equal 1, summary.results.size
        end
      end
    end
  end
end
