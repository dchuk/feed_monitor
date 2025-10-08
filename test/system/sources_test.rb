# frozen_string_literal: true

require "application_system_test_case"

module FeedMonitor
  class SourcesTest < ApplicationSystemTestCase
    test "creating a source via the UI" do
      assert_difference("FeedMonitor::Source.count", 1) do
        visit feed_monitor.new_source_path

        fill_in "Name", with: "UI Source"
        fill_in "Feed url", with: "https://example.com/feed"
        fill_in "Website url", with: "https://example.com"
        fill_in "Fetch interval hours", with: "4"
        fill_in "Scraper adapter", with: "readability"

        click_button "Create Source"
      end

      assert_current_path feed_monitor.root_path
      assert FeedMonitor::Source.exists?(feed_url: "https://example.com/feed")
    end
  end
end
