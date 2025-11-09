# frozen_string_literal: true

require "test_helper"
require "rake"

class RecoverStalledFetchesTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("feedmon:maintenance:recover_stalled_fetches")
  end

  test "delegates to stalled fetch reconciler and reports summary" do
    task = Rake::Task["feedmon:maintenance:recover_stalled_fetches"]
    task.reenable

    now = Time.current
    stubbed_result = Feedmon::Fetching::StalledFetchReconciler::Result.new(
      recovered_source_ids: [ 1, 2 ],
      jobs_removed: [ 101 ],
      executed_at: now
    )

    output = nil

    Feedmon::Fetching::StalledFetchReconciler.stub(:call, ->(**_args) { stubbed_result }) do
      output = capture_io { task.invoke }.first
    end

    assert_match(/Recovered 2 stalled sources/i, output)
    assert_match(/Removed 1 orphaned job/i, output)
  end
end
