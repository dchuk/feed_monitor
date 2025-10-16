# frozen_string_literal: true

require "rails/generators"
require "rails/generators/base"

module FeedMonitor
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      class_option :mount_path,
        type: :string,
        default: "/feed_monitor",
        desc: "Path the engine will mount at inside the host application's routes"

      def add_routes_mount
        mount_path = normalized_mount_path
        return if engine_already_mounted?(mount_path)

        route %(mount FeedMonitor::Engine, at: "#{mount_path}")
      end

      def create_initializer
        initializer_path = "config/initializers/feed_monitor.rb"
        destination = File.join(destination_root, initializer_path)

        if File.exist?(destination)
          say_status :skip, initializer_path, :yellow
          return
        end

        template "feed_monitor.rb.tt", initializer_path
      end

      private

      def engine_already_mounted?(mount_path)
        routes_path = File.join(destination_root, "config/routes.rb")
        return false unless File.exist?(routes_path)

        routes_content = File.read(routes_path)
        routes_content.include?("mount FeedMonitor::Engine, at: \"#{mount_path}\"") ||
          routes_content.include?("mount FeedMonitor::Engine")
      end

      def normalized_mount_path
        raw_path = options.key?(:mount_path) ? options[:mount_path] : "/feed_monitor"
        path = (raw_path && !raw_path.strip.empty?) ? raw_path.strip : "/feed_monitor"
        path.start_with?("/") ? path : "/#{path}"
      end
    end
  end
end
