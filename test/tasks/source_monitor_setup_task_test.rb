# frozen_string_literal: true

require "test_helper"
require "rake"

class SourceMonitorSetupTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("source_monitor:setup:check")
  end

  test "prints summary and raises when dependencies missing" do
    task = Rake::Task["source_monitor:setup:check"]
    task.reenable

    result = SourceMonitor::Setup::DependencyChecker::Result.new(
      key: :ruby,
      name: "Ruby",
      status: :error,
      current: Gem::Version.new("3.0.0"),
      expected: ">= 3.4.4",
      remediation: "Upgrade Ruby"
    )

    summary = SourceMonitor::Setup::DependencyChecker::Summary.new([ result ])

    checker = Minitest::Mock.new
    checker.expect(:call, summary)

    SourceMonitor::Setup::DependencyChecker.stub(:new, ->(*) { checker }) do
      error = assert_raises(RuntimeError) do
        capture_io { task.invoke }
      end

      assert_match(/Ruby.*upgrade/i, error.message)
    end

    checker.verify
  end

  test "verify task prints summary and raises on failure" do
    task = Rake::Task["source_monitor:setup:verify"]
    task.reenable

    summary = SourceMonitor::Setup::Verification::Summary.new([
      SourceMonitor::Setup::Verification::Result.new(key: :solid_queue, name: "Solid Queue", status: :error, details: "missing", remediation: "fix")
    ])

    runner = Minitest::Mock.new
    runner.expect(:call, summary)

    printer = Minitest::Mock.new
    printer.expect(:print, nil, [ summary ])

    SourceMonitor::Setup::Verification::Runner.stub(:new, ->(*) { runner }) do
      SourceMonitor::Setup::Verification::Printer.stub(:new, printer) do
        assert_raises(RuntimeError) { task.invoke }
      end
    end

    runner.verify
    printer.verify
  end
end
