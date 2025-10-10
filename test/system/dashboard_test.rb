# frozen_string_literal: true

require "application_system_test_case"
require "securerandom"
require "nokogiri"

module FeedMonitor
  class DashboardTest < ApplicationSystemTestCase
    def setup
      super
      FeedMonitor.reset_configuration!
      FeedMonitor::Jobs::Visibility.reset!
      FeedMonitor::Jobs::Visibility.setup!
      purge_solid_queue_tables
      FeedMonitor::Dashboard::TurboBroadcaster.setup!
    end

    def teardown
      FeedMonitor.reset_configuration!
      FeedMonitor::Jobs::Visibility.reset!
      purge_solid_queue_tables
      super
    end

    test "dashboard displays stats, job metrics, and quick actions" do
      FeedMonitor.configure do |config|
        config.mission_control_enabled = true
        config.mission_control_dashboard_path = -> { FeedMonitor::Engine.routes.url_helpers.root_path }
      end

      source = Source.create!(name: "Example", feed_url: "https://example.com/feed", next_fetch_at: 1.hour.from_now)
      Item.create!(source:, guid: "item-1", url: "https://example.com/item")
      FetchLog.create!(source:, success: true, items_created: 1, items_updated: 0, started_at: Time.current)
      ScrapeLog.create!(source:, item: source.items.first, success: false, scraper_adapter: "readability", started_at: 5.minutes.ago)

      seed_queue_activity

      visit feed_monitor.root_path

      assert_text "Overview"
      assert_text "Recent Activity"
      assert_text "Quick Actions"
      assert_text "Job Queues"

      within "#feed_monitor_dashboard_stats" do
        sources_card = find(:xpath, ".//div[./dt[text()='Sources']]")
        within sources_card do
          assert_text "1"
        end
      end

      assert_selector "span", text: "Success"
      assert_selector "span", text: "Failure"
      assert_selector "a", text: "Go", count: 3

      adapter_label = FeedMonitor::Jobs::Visibility.adapter_name.to_s
      assert_text adapter_label
      assert_text FeedMonitor.queue_name(:fetch)
      assert_text FeedMonitor.queue_name(:scrape)
      assert_text "Ready"
      assert_text "Scheduled"
      assert_text "Failed"
      assert_text "Recurring Tasks"
      assert_text "Total: 3"
      assert_text "Paused"
      assert_text "No jobs queued for this role yet."
      assert_selector "a", text: "Open Mission Control"
    end

    test "dashboard streams new items and fetch completions" do
      source = Source.create!(name: "Streamed Source", feed_url: "https://example.com/feed", next_fetch_at: 1.minute.from_now)

      visit feed_monitor.dashboard_path
      connect_turbo_cable_stream_sources
      assert_selector "turbo-cable-stream-source", visible: :all, wait: 5

      initial_item_count = Item.count
      streamable = FeedMonitor::Dashboard::TurboBroadcaster::STREAM_NAME
      item = Item.create!(
        source:,
        guid: "turbo-item-#{SecureRandom.hex(4)}",
        url: "https://example.com/items/#{SecureRandom.hex(4)}",
        title: "Turbo Arrival"
      )

      item_messages = capture_turbo_stream_broadcasts(streamable) do
        FeedMonitor::Dashboard::TurboBroadcaster.broadcast_dashboard_updates
      end
      assert item_messages.any?, "expected turbo broadcasts for dashboard updates"
      apply_turbo_stream_messages(item_messages)

      within "#feed_monitor_dashboard_stats" do
        assert_selector :xpath,
          ".//dt[text()='Items']/following-sibling::dd[1]",
          text: (initial_item_count + 1).to_s,
          wait: 5
      end

      within "#feed_monitor_dashboard_recent_activity" do
        assert_text "Turbo Arrival", wait: 5
        assert_text "ITEM", wait: 5
      end

      fetch_log = FetchLog.create!(
        source:,
        success: true,
        items_created: 1,
        items_updated: 0,
        started_at: Time.current
      )

      fetch_messages = capture_turbo_stream_broadcasts(streamable) do
        FeedMonitor::Dashboard::TurboBroadcaster.broadcast_dashboard_updates
      end
      assert fetch_messages.any?, "expected turbo broadcasts for dashboard updates"
      apply_turbo_stream_messages(fetch_messages)

      within "#feed_monitor_dashboard_recent_activity" do
        assert_text "Fetch ##{fetch_log.id}", wait: 5
      end
    end

    private

    def seed_queue_activity
      fetch_queue = FeedMonitor.queue_name(:fetch)

      SolidQueue::Job.create!(
        queue_name: fetch_queue,
        class_name: "FeedMonitor::FetchFeedJob",
        arguments: []
      )

      SolidQueue::Job.create!(
        queue_name: fetch_queue,
        class_name: "FeedMonitor::FetchFeedJob",
        arguments: [],
        scheduled_at: 10.minutes.from_now
      )

      failed_job = SolidQueue::Job.create!(
        queue_name: fetch_queue,
        class_name: "FeedMonitor::FetchFeedJob",
        arguments: []
      )
      failed_job.ready_execution&.destroy!
      SolidQueue::FailedExecution.create!(job: failed_job, error: "RuntimeError: boom")

      SolidQueue::Pause.create!(queue_name: fetch_queue)
    end

    def purge_solid_queue_tables
      [
        ::SolidQueue::RecurringExecution,
        ::SolidQueue::RecurringTask,
        ::SolidQueue::ClaimedExecution,
        ::SolidQueue::FailedExecution,
        ::SolidQueue::BlockedExecution,
        ::SolidQueue::ScheduledExecution,
        ::SolidQueue::ReadyExecution,
        ::SolidQueue::Process,
        ::SolidQueue::Pause,
        ::SolidQueue::Job
      ].each do |model|
        next unless model.table_exists?

        model.delete_all
      end
    end

    def apply_turbo_stream_messages(messages)
      Array(messages).each do |payload|
        turbo_nodes =
          case payload
          when Nokogiri::XML::Node
            [ payload ]
          else
            message = payload.is_a?(Hash) ? payload["message"] : payload
            next if message.blank?

            parse_turbo_streams(message)
          end

        turbo_nodes.each do |node|
          action = node.attributes["action"]&.value
          target = node.attributes["target"]&.value
          html = node.at_css("template")&.children&.map(&:to_s)&.join
          next if action.blank? || target.blank? || html.blank?

          case action
          when "replace"
            page.execute_script(
              "const target = document.getElementById(arguments[0]); if (target) { target.outerHTML = arguments[1]; }",
              target,
              html
            )
          when "append"
            page.execute_script(
              "const target = document.getElementById(arguments[0]); if (target) { target.insertAdjacentHTML('beforeend', arguments[1]); }",
              target,
              html
            )
          when "prepend"
            page.execute_script(
              "const target = document.getElementById(arguments[0]); if (target) { target.insertAdjacentHTML('afterbegin', arguments[1]); }",
              target,
              html
            )
          end
        end
      end
    end

    def parse_turbo_streams(message)
      document = Nokogiri::XML(message)
      document.css("turbo-stream").map do |node|
        action = node.attributes["action"]&.value
        target = node.attributes["target"]&.value
        html = node.at_css("template")&.children&.map(&:to_s)&.join
        next if action.blank? || target.blank? || html.blank?

        transformed = Nokogiri::XML::Element.new("turbo-stream", document)
        transformed["action"] = action
        transformed["target"] = target
        template = Nokogiri::XML::Element.new("template", document)
        template.inner_html = html
        transformed.add_child(template)
        transformed
      end.compact
    end
  end
end
