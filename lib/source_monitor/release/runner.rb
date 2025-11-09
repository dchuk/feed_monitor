# frozen_string_literal: true

require "tempfile"
require "source_monitor/release/changelog"

module SourceMonitor
  module Release
    class Runner
      CommandFailure = Class.new(StandardError)

      QUALITY_COMMANDS = [
        [ "bin/rubocop" ],
        [ "bin/brakeman", "--no-pager" ],
        [ "bin/test-coverage" ],
        [ "bin/check-diff-coverage" ]
      ].freeze
      GEM_BUILD_COMMAND = [ "rbenv", "exec", "gem", "build", "source_monitor.gemspec" ].freeze

      def initialize(version:, executor: Executor.new, changelog: Changelog.new)
        @version = version
        @executor = executor
        @changelog = changelog
      end

      def call
        validate_version!
        run_commands(QUALITY_COMMANDS)
        run_command(GEM_BUILD_COMMAND)
        create_annotated_tag
        true
      end

      private

      attr_reader :version, :executor, :changelog

      def run_commands(commands)
        commands.each do |command|
          run_command(command)
        end
      end

      def run_command(command, env: {})
        success = executor.run(command, env:)
        return if success

        raise CommandFailure, "Command failed: #{command.join(' ')}"
      end

      def create_annotated_tag
        message = changelog.annotation_for(version)

        Tempfile.create([ "feed-monitor-release", ".log" ]) do |file|
          file.write(message)
          file.flush
          file.rewind

          run_command([ "git", "tag", "-a", "v#{version}", "-F", file.path ])
        end
      end

      def validate_version!
        raise ArgumentError, "version must be provided" if version.to_s.strip.empty?
      end

      class Executor
        def run(command, env: {})
          system(env, *command)
        end
      end
    end
  end
end
