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

        test "uses default verifiers" do
          queue_result = Result.new(key: :solid_queue, name: "Solid Queue", status: :ok, details: "ok")
          action_result = Result.new(key: :action_cable, name: "Action Cable", status: :ok, details: "ok")

          callable = Class.new do
            attr_reader :calls

            def initialize(result)
              @result = result
              @calls = 0
            end

            def call
              @calls += 1
              @result
            end
          end

          original_queue = SolidQueueVerifier
          original_action = ActionCableVerifier

          queue_class = Class.new do
            attr_reader :calls

            define_method(:initialize) do
              @calls = 0
            end

            define_method(:call) do
              @calls += 1
              queue_result
            end
          end

          action_class = Class.new do
            attr_reader :calls

            define_method(:initialize) do
              @calls = 0
            end

            define_method(:call) do
              @calls += 1
              action_result
            end
          end

          SourceMonitor::Setup::Verification.send(:remove_const, :SolidQueueVerifier)
          SourceMonitor::Setup::Verification.const_set(:SolidQueueVerifier, queue_class)
          SourceMonitor::Setup::Verification.send(:remove_const, :ActionCableVerifier)
          SourceMonitor::Setup::Verification.const_set(:ActionCableVerifier, action_class)

          runner = Runner.new
          summary = runner.call
          assert_equal 2, summary.results.size
          assert summary.ok?
          defaults = runner.send(:default_verifiers)
          assert_equal 2, defaults.size
          assert_instance_of queue_class, defaults.first
          assert_instance_of action_class, defaults.last
        ensure
          SourceMonitor::Setup::Verification.send(:remove_const, :SolidQueueVerifier)
          SourceMonitor::Setup::Verification.const_set(:SolidQueueVerifier, original_queue)
          SourceMonitor::Setup::Verification.send(:remove_const, :ActionCableVerifier)
          SourceMonitor::Setup::Verification.const_set(:ActionCableVerifier, original_action)
        end
      end
    end
  end
end
