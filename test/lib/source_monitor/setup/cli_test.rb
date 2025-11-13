require "test_helper"

module SourceMonitor
  module Setup
    class CLITest < ActiveSupport::TestCase
      test "install command delegates to workflow and prints summary" do
        workflow = Minitest::Mock.new
        summary = SourceMonitor::Setup::Verification::Summary.new([])
        workflow.expect(:run, summary)

        printer = Minitest::Mock.new
        printer.expect(:print, nil, [ summary ])

        SourceMonitor::Setup::Workflow.stub(:new, ->(*) { workflow }) do
          SourceMonitor::Setup::Verification::Printer.stub(:new, printer) do
            CLI.start([ "install", "--mount-path=/monitor" ])
          end
        end

        workflow.verify
        printer.verify
        assert_mock workflow
        assert_mock printer
      end

      test "verify command runs runner" do
        summary = SourceMonitor::Setup::Verification::Summary.new([])
        runner = Minitest::Mock.new
        runner.expect(:call, summary)
        printer = Minitest::Mock.new
        printer.expect(:print, nil, [ summary ])

        SourceMonitor::Setup::Verification::Runner.stub(:new, ->(*) { runner }) do
          SourceMonitor::Setup::Verification::Printer.stub(:new, printer) do
            CLI.start([ "verify" ])
          end
        end

        runner.verify
        printer.verify
        assert_mock runner
        assert_mock printer
      end
    end
  end
end
