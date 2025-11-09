# frozen_string_literal: true

require "pathname"

module SourceMonitor
  module Release
    class Changelog
      MissingEntryError = Class.new(StandardError)

      def initialize(path: default_path)
        @path = Pathname.new(path)
      end

      def latest_entry
        @latest_entry ||= begin
          sections = extract_sections
          heading = sections.keys.find { |key| key != "## Release Checklist" }
          raise MissingEntryError, "Unable to find changelog entry after Release Checklist" unless heading

          content = ([ heading ] + sections.fetch(heading)).join
          content.rstrip
        end
      end

      def annotation_for(version)
        raise ArgumentError, "version must be provided" if version.to_s.strip.empty?

        [ "SourceMonitor v#{version}", latest_entry ].join("\n\n")
      end

      private

      attr_reader :path

      def default_path
        Pathname.new(__dir__).join("..", "..", "..", "CHANGELOG.md").expand_path
      end

      def extract_sections
        sections = {}
        current_heading = nil

        File.foreach(path) do |line|
          if line.start_with?("## ")
            current_heading = line.strip
            sections[current_heading] ||= []
            next
          end

          next unless current_heading

          sections[current_heading] << line
        end

        sections
      end
    end
  end
end
