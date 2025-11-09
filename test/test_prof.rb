# frozen_string_literal: true

require "test_prof"
require "test_prof/recipes/minitest/before_all"
require "test_prof/recipes/minitest/sample"

TestProf.configure do |config|
  # Disable timestamped filenames so artifacts are easy to diff in CI.
  config.timestamps = false if config.respond_to?(:timestamps=)
end

# Allow running focused subsets locally using SAMPLE/SAMPLE_GROUPS env vars.
TestProf::MinitestSample.call

module Feedmon
  module TestProfSupport
    module SetupOnce
      def setup_once(setup_fixtures: false, &block)
        before_all(setup_fixtures: setup_fixtures, &block)
      end
    end

    module InlineJobs
      def with_inline_jobs
        previous = ActiveJob::Base.queue_adapter
        ActiveJob::Base.queue_adapter = :inline
        yield
      ensure
        ActiveJob::Base.queue_adapter = previous
      end
    end
  end
end

ActiveSupport::TestCase.include TestProf::BeforeAll::Minitest
ActiveSupport::TestCase.extend Feedmon::TestProfSupport::SetupOnce
ActiveSupport::TestCase.include Feedmon::TestProfSupport::InlineJobs
