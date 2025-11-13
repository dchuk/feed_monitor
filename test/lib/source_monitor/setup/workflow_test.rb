require "test_helper"

module SourceMonitor
  module Setup
    class WorkflowTest < ActiveSupport::TestCase
      class StubSummary < SourceMonitor::Setup::DependencyChecker::Summary
        def initialize(status: :ok)
          @status = status
          super([])
        end

        def overall_status
          @status
        end

        def ok?
          overall_status == :ok
        end

        def errors?
          overall_status == :error
        end

        def errors
          []
        end
      end

      class Spy
        attr_reader :calls

        def initialize(result = nil)
          @result = result
          @calls = []
        end

        def method_missing(name, *args, **kwargs)
          @calls << [ name, args, kwargs ]
          @result
        end

        def respond_to_missing?(*_args)
          true
        end
      end

      test "run orchestrates all installers and prompts for devise" do
        dependency_checker = Minitest::Mock.new
        dependency_checker.expect(:call, StubSummary.new(status: :ok))

        gemfile_editor = Spy.new(true)
        bundle_installer = Spy.new
        node_installer = Spy.new
        install_generator = Spy.new
        migration_installer = Spy.new
        initializer_patcher = Spy.new

        prompter = Minitest::Mock.new
        prompter.expect(:ask, "/admin/monitor", [ String ], default: Workflow::DEFAULT_MOUNT_PATH)
        prompter.expect(:yes?, true, [ String ], default: true)

        verifier = Spy.new(SourceMonitor::Setup::Verification::Summary.new([]))

        workflow = Workflow.new(
          dependency_checker: dependency_checker,
          prompter: prompter,
          gemfile_editor: gemfile_editor,
          bundle_installer: bundle_installer,
          node_installer: node_installer,
          install_generator: install_generator,
          migration_installer: migration_installer,
          initializer_patcher: initializer_patcher,
          devise_detector: -> { true },
          verifier: verifier
        )

        workflow.run

        assert_equal :ensure_entry, gemfile_editor.calls.first.first
        assert_equal :install, bundle_installer.calls.first.first
        assert_equal :install_if_needed, node_installer.calls.first.first
        assert_equal :run, install_generator.calls.first.first
        assert_equal "/admin/monitor", install_generator.calls.first[2][:mount_path]
        assert_equal :install, migration_installer.calls.first.first
        assert_equal :ensure_navigation_hint, initializer_patcher.calls.first.first
        initializer_patcher.calls.detect { |call| call.first == :ensure_devise_hooks }
        assert_equal :call, verifier.calls.first.first

        dependency_checker.verify
        prompter.verify
      end

      test "raises when dependencies fail" do
        dependency_checker = Minitest::Mock.new
        summary = StubSummary.new(status: :error)
        def summary.errors
          [ SourceMonitor::Setup::DependencyChecker::Result.new(key: :ruby, name: "Ruby", status: :error, remediation: "update") ]
        end
        dependency_checker.expect(:call, summary)

        workflow = Workflow.new(dependency_checker: dependency_checker)

        error = assert_raises(Workflow::RequirementError) { workflow.run }
        assert_match(/Ruby/, error.message)
      end
    end
  end
end
