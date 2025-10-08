# frozen_string_literal: true

require "application_system_test_case"

module FeedMonitor
  class SourcesTest < ApplicationSystemTestCase
    test "managing a source end to end" do
      visit feed_monitor.sources_path

      assert_difference("FeedMonitor::Source.count", 1) do
        click_link "New Source", match: :first

        fill_in "Name", with: "UI Source"
        fill_in "Feed url", with: "https://example.com/feed"
        fill_in "Website url", with: "https://example.com"
        fill_in "Fetch interval hours", with: "4"
        fill_in "Scraper adapter", with: "readability"

        click_button "Create Source"
      end

      assert_current_path feed_monitor.source_path(FeedMonitor::Source.last)
      assert_text "Source created successfully"

      source = FeedMonitor::Source.last

      FeedMonitor::Item.create!(
        source: source,
        guid: "ui-item-1",
        title: "UI Item Article",
        url: "https://example.com/articles/ui",
        summary: "Monitoring summary for UI validations.",
        scrape_status: "success",
        published_at: Time.current
      )

      visit feed_monitor.source_path(source)

      assert_selector "[data-testid='source-items-table']"
      assert_text "UI Item Article"

      click_link "Edit"
      fill_in "Name", with: "Updated Source"
      uncheck "Active"
      click_button "Update Source"

      assert_current_path feed_monitor.source_path(source)
      assert_text "Source updated successfully"
      assert_text "Updated Source"

      click_link "Sources"
      assert_current_path feed_monitor.sources_path
      assert_text "Updated Source"
      assert_selector "span", text: "Paused"

      assert_difference("FeedMonitor::Source.count", -1) do
        visit feed_monitor.source_path(source)
        click_button "Delete"
      end

      assert_current_path feed_monitor.sources_path
      assert_text "Source deleted"
      assert_no_text "Updated Source"
    end
  end
end
