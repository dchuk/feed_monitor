# frozen_string_literal: true

require "application_system_test_case"
require "uri"

module FeedMonitor
  class SourcesTest < ApplicationSystemTestCase
    include ActiveJob::TestHelper

    setup do
      ActiveJob::Base.queue_adapter = :test
      clear_enqueued_jobs
    end

    teardown do
      clear_enqueued_jobs
    end
    test "managing a source end to end" do
      visit feed_monitor.sources_path

      within "header nav" do
        assert_no_link "New Source"
      end

      assert_selector "th", text: /New Items \/ Day/i
      assert_selector "[data-testid='fetch-interval-heatmap']"

      click_link "New Source", match: :first

      fill_in "Name", with: "UI Source"
      fill_in "Feed url", with: "https://example.com/feed"
      fill_in "Website url", with: "https://example.com"
      fill_in "Fetch interval (minutes)", with: "240"
      fill_in "Retention window (days)", with: "14"
      fill_in "Maximum stored items", with: "200"
      select "Readability", from: "Scraper adapter"

      click_button "Create Source"
      assert_selector "h1", text: "UI Source"
      source = FeedMonitor::Source.find_by!(feed_url: "https://example.com/feed")
      assert_equal "UI Source", source.name
      assert_current_path feed_monitor.source_path(FeedMonitor::Source.last)
      assert_text "Retention Policy Active"

      source = FeedMonitor::Source.last

      FeedMonitor::Item.create!(
        source: source,
        guid: "ui-item-1",
        title: "UI Item Article",
        url: "https://example.com/articles/ui",
        summary: "Monitoring summary for UI validations.",
        categories: %w[news analytics],
        tags: %w[ruby rails],
        scrape_status: "success",
        published_at: Time.current
      )

      visit feed_monitor.source_path(source)

      assert_selector "[data-testid='source-items-table']"
      assert_text "UI Item Article"
      within "[data-testid='source-items-table'] thead" do
        assert_text(/Categories/i)
        assert_text(/Tags/i)
      end
      within "[data-testid='source-items-table'] tbody tr:first-child" do
        assert_text "news, analytics"
        assert_text "ruby, rails"
      end

      click_link "Edit"
      fill_in "Name", with: "Updated Source"
      uncheck "Active"
      click_button "Update Source"

      assert_current_path feed_monitor.source_path(source)
      assert_text "Updated Source"

      click_link "Sources"
      assert_current_path feed_monitor.sources_path
      assert_text "Updated Source"
      assert_selector "span", text: "Paused"
      within find("tr", text: "Updated Source") do
        assert_selector "td", text: %r{/ day}
      end

      visit feed_monitor.source_path(source)
      accept_confirm do
        click_button "Delete"
      end
      assert_no_text "Updated Source"
      refute FeedMonitor::Source.exists?(source.id)

      assert_current_path feed_monitor.sources_path
      assert_no_text "Updated Source"
    end

    test "searching sources filters the list" do
      create_source!(name: "Ruby Updates", feed_url: "https://ruby.example.com/feed.xml")
      create_source!(name: "Elixir News", feed_url: "https://elixir.example.com/feed.xml")

      visit feed_monitor.sources_path

      assert_text "Ruby Updates"
      assert_text "Elixir News"

      fill_in "Search sources", with: "Ruby"
      click_button "Search"

      assert_text "Ruby Updates"
      assert_no_text "Elixir News"
      assert_text "Showing results for"

      click_link "Clear search"

      assert_text "Ruby Updates"
      assert_text "Elixir News"
    end

    test "filtering sources via fetch interval heatmap" do
      create_source!(name: "Quick Source", fetch_interval_minutes: 15, feed_url: "https://quick.example.com/feed.xml")
      create_source!(name: "Regular Source", fetch_interval_minutes: 45, feed_url: "https://regular.example.com/feed.xml")
      create_source!(name: "Slow Source", fetch_interval_minutes: 95, feed_url: "https://slow.example.com/feed.xml")

      visit feed_monitor.sources_path

      find("[data-testid='fetch-interval-bucket-30-60']").click

      assert_text "Filtered by fetch interval"
      assert_text "Regular Source"
      assert_no_text "Quick Source"
      assert_no_text "Slow Source"

      within "[data-testid='fetch-interval-bucket-5-30']" do
        assert_text "1"
      end

      within "[data-testid='fetch-interval-bucket-60-120']" do
        assert_text "1"
      end

      click_link "Clear interval filter"

      assert_text "Quick Source"
      assert_text "Regular Source"
      assert_text "Slow Source"
    end

    test "sources table supports sorting and dropdown actions" do
      FeedMonitor::Source.delete_all
      older = create_source!(name: "Alpha Feed", feed_url: "https://alpha.example.com/feed.xml")
      newer = create_source!(name: "Zeta Feed", feed_url: "https://zeta.example.com/feed.xml")
      older.update_columns(created_at: 1.hour.ago)
      newer.update_columns(created_at: Time.current)

      visit feed_monitor.sources_path

      assert_source_order [ "Zeta Feed", "Alpha Feed" ]

      within "turbo-frame#feed_monitor_sources_table thead" do
        click_link "Source"
      end

      assert_source_order [ "Alpha Feed", "Zeta Feed" ]
      within "turbo-frame#feed_monitor_sources_table thead th[data-sort-column='name']" do
        assert_text "▲"
      end

      within "turbo-frame#feed_monitor_sources_table thead" do
        click_link "Source"
      end
      assert_source_order [ "Zeta Feed", "Alpha Feed" ]
      within "turbo-frame#feed_monitor_sources_table thead th[data-sort-column='name']" do
        assert_text "▼"
      end

      within "turbo-frame#feed_monitor_sources_table" do
        first_row = find("tbody tr:first-child")
        within first_row do
          name_link = find("td:first-child a", text: "Zeta Feed")
          assert_equal feed_monitor.source_path(newer), URI.parse(name_link[:href]).path

          assert_no_link "View"
          assert_no_link "Edit"

          find("button[aria-label='Source actions']").click
          assert_link "View"
          assert_link "Edit"

          menu = find("[data-dropdown-target='menu']", visible: :all)
          assert_not menu[:class].to_s.split.include?("hidden"), "dropdown menu should be visible after toggle"

          find(:xpath, "//body").click
          assert menu[:class].to_s.split.include?("hidden"), "dropdown menu should be hidden after click outside"
        end
      end
    end

    test "source dropdown links navigate to view and edit pages" do
      FeedMonitor::Source.delete_all
      source = create_source!(name: "Nav Feed", feed_url: "https://nav.example.com/feed.xml")

      visit feed_monitor.sources_path

      within "turbo-frame#feed_monitor_sources_table" do
        find("button[aria-label='Source actions']").click
        click_link "View"
      end

      assert_current_path feed_monitor.source_path(source)

      visit feed_monitor.sources_path

      within "turbo-frame#feed_monitor_sources_table" do
        find("button[aria-label='Source actions']").click
        click_link "Edit"
      end

      assert_current_path feed_monitor.edit_source_path(source)
    end

    test "source show renders scrape status badges and consumes turbo broadcasts" do
      source = create_source!(
        name: "Turbo Status",
        feed_url: "https://turbo.example.com/feed.xml",
        scraping_enabled: true
      )
      item = source.items.create!(
        guid: "turbo-item-1",
        title: "Turbo Item",
        url: "https://turbo.example.com/articles/1",
        published_at: Time.current
      )

      visit feed_monitor.source_path(source)

      within "[data-testid='source-items-table'] tbody tr:first-child" do
        badge = find("[data-testid='item-scrape-status-badge']")
        assert_equal "idle", badge["data-status"]
        assert_text "Not scraped"
        assert_no_text "Scraped"
      end

      item.update!(scrape_status: "success", scraped_at: Time.current)
      source.reload

      payloads = capture_turbo_stream_broadcasts([source, :details]) do
        FeedMonitor::Realtime.broadcast_source(source)
      end
      assert_not_empty payloads, "expected a turbo-stream broadcast for source details"

      payloads.each do |payload|
        page.execute_script("Turbo.renderStreamMessage(arguments[0])", payload.to_html)
      end

      within "[data-testid='source-items-table'] tbody tr:first-child" do
        badge = find("[data-testid='item-scrape-status-badge']")
        assert_equal "success", badge["data-status"]
        assert_text "Scraped"
      end
    end

    test "bulk scrape form enqueues selections and handles empty scopes" do
      FeedMonitor.configure do |config|
        config.scraping.max_in_flight_per_source = 5
      end

      source = create_source!(name: "Bulk Scrape", scraping_enabled: true, auto_scrape: false)
      3.times do |index|
        FeedMonitor::Item.create!(
          source: source,
          guid: "bulk-item-#{index}",
          url: "https://example.com/bulk/#{index}",
          title: "Bulk Item #{index}",
          published_at: Time.current - index.minutes
        )
      end

      visit feed_monitor.source_path(source)

      within "[data-testid='bulk-scrape-form']" do
        assert_selector "label[data-testid='bulk-scrape-option-current']", text: /Current view/i
        assert_selector "label[data-testid='bulk-scrape-option-unscraped']", text: /Unscraped items/i
      end

      within "[data-testid='bulk-scrape-form']" do
        accept_confirm do
          click_button "Scrape Selected"
        end
      end

      assert_text "Queued scraping for 3 items"
      source.reload
      assert_equal 3, source.items.where(scrape_status: "pending").count
      within "[data-testid='source-items-table'] tbody tr:first-child" do
        assert_selector "[data-testid='item-scrape-status-badge'][data-status='pending']"
      end

      within "[data-testid='bulk-scrape-form']" do
        find("label[data-testid='bulk-scrape-option-unscraped']").click
        accept_confirm do
          click_button "Scrape Selected"
        end
      end

      assert_text "No items match the selected scope"
      source.reload
      assert_equal 3, source.items.where(scrape_status: "pending").count
    end

    private

    def assert_source_order(expected)
      within "turbo-frame#feed_monitor_sources_table" do
        expected.each_with_index do |name, index|
          assert_selector :xpath,
            format(".//tbody/tr[%<row>d]/td[1]", row: index + 1),
            text: /\A#{Regexp.escape(name)}/
        end
      end
    end

    test "manually fetching a source" do
      FeedMonitor::Item.delete_all
      FeedMonitor::Source.delete_all

      source = create_source!(
        name: "Fetchable Source",
        feed_url: "https://www.ruby-lang.org/en/feeds/news.rss"
      )

      visit feed_monitor.source_path(source)

      click_button "Fetch Now"
      assert_selector "[data-testid='fetch-status-badge']", text: "Queued"

      VCR.use_cassette("feed_monitor/fetching/rss_success") do
        perform_enqueued_jobs
      end

      visit feed_monitor.source_path(source)

      assert_selector "[data-testid='source-items-table'] tbody tr", minimum: 1

      source.reload
      assert source.items_count.positive?, "expected items_count to increase"

      log = source.fetch_logs.order(:created_at).last
      total_processed = log.items_created + log.items_updated
      assert_equal source.items_count, total_processed
      assert_equal 0, log.items_failed
    end

    test "retrying a failed source queues a forced fetch" do
      FeedMonitor::Source.delete_all

      source = create_source!(
        name: "Unstable Feed",
        feed_url: "https://unstable.example.com/feed.xml"
      )

      source.update!(
        fetch_status: "failed",
        fetch_retry_attempt: 0,
        failure_count: 6,
        fetch_circuit_opened_at: 1.minute.ago,
        fetch_circuit_until: 1.hour.from_now
      )

      visit feed_monitor.source_path(source)

      assert_button "Retry Now"
      assert_selector "[data-testid='fetch-status-badge']", text: "Failed"

      click_button "Retry Now"

      assert_selector "[data-testid='fetch-status-badge']", text: "Queued"
    end

    test "auto paused sources show auto paused badge" do
      FeedMonitor::Source.delete_all

      source = create_source!(
        name: "Flaky Feed",
        feed_url: "https://flaky.example.com/feed.xml",
        health_status: "auto_paused",
        auto_paused_at: Time.current,
        auto_paused_until: 2.hours.from_now
      )

      visit feed_monitor.sources_path

      within find("tr", text: source.name) do
        assert_selector "span", text: "Auto-Paused"
      end
    end
  end
end
