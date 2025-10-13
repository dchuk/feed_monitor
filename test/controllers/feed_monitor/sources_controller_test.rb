# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  class SourcesControllerTest < ActionDispatch::IntegrationTest
    include ActionView::RecordIdentifier

    test "sanitizes attributes when creating a source" do
      assert_difference -> { Source.count }, 1 do
        post "/feed_monitor/sources", params: {
          source: {
            name: "<script>alert(1)</script>Example Source",
            feed_url: "https://example.com/feed.xml",
            website_url: "https://example.com",
            fetch_interval_minutes: 60,
            scrape_settings: {
              selectors: {
                content: "<script>danger()</script>",
                title: "<img src=x onerror=alert(1)>Headline"
              }
            }
          }
        }
      end

      source = Source.order(:created_at).last

      assert_redirected_to "/feed_monitor/sources/#{source.id}"

      assert_equal "alert(1)Example Source", source.name
      refute_includes source.name, "<"

      content_selector = source.scrape_settings.dig("selectors", "content")
      title_selector = source.scrape_settings.dig("selectors", "title")

      assert_equal "danger()", content_selector
      refute_includes title_selector, "<"
      refute_includes title_selector, ">"
    end

    test "sanitizes search params before rendering" do
      get "/feed_monitor/sources", params: {
        q: {
          "name_or_feed_url_or_website_url_cont" => "<script>alert(2)</script>"
        }
      }

      assert_response :success
      response_body = response.body
      refute_includes response_body, "%3Cscript"
      refute_includes response_body, "&lt;script"
      assert_includes response_body, "value=\"alert(2)\""
    end

    test "destroy removes source and dependents via turbo stream" do
      keep_source = create_source!(name: "Keep", feed_url: "https://keep.example.com/feed.xml")
      source = create_source!(name: "Remove", feed_url: "https://remove.example.com/feed.xml")

      item = source.items.create!(
        guid: "guid-1",
        title: "Item",
        url: "https://example.com/1",
        published_at: Time.current
      )
      source.fetch_logs.create!(success: true, started_at: Time.current, completed_at: Time.current, items_created: 1)
      source.scrape_logs.create!(
        item: item,
        success: true,
        started_at: Time.current,
        completed_at: Time.current,
        scraper_adapter: "readability"
      )

      assert_difference [
        -> { FeedMonitor::Source.count },
        -> { FeedMonitor::Item.count },
        -> { FeedMonitor::FetchLog.count },
        -> { FeedMonitor::ScrapeLog.count }
      ], -1 do
        delete feed_monitor.source_path(source), params: { q: { "name_or_feed_url_or_website_url_cont" => "Keep" } }, as: :turbo_stream
      end

      assert_response :success
      assert_equal "text/vnd.turbo-stream.html", response.media_type
      assert_includes response.body, %(<turbo-stream action="remove" target="#{dom_id(source, :row)}">)
      assert_includes response.body, %(<turbo-stream action="replace" target="feed_monitor_sources_heatmap">)
      assert_includes response.body, %(<turbo-stream action="append" target="feed_monitor_notifications">)

      assert FeedMonitor::Source.exists?(keep_source.id), "expected other sources to remain"
      refute FeedMonitor::Item.exists?(item.id), "expected associated items to be deleted"
    end

    test "destroy turbo stream includes redirect when redirect_to provided" do
      source = create_source!(name: "Redirected", feed_url: "https://redirect.example.com/feed.xml")

      delete feed_monitor.source_path(source),
        params: { redirect_to: feed_monitor.sources_path },
        as: :turbo_stream

      assert_response :success
      assert_includes response.body, %(<turbo-stream action="append" target="feed_monitor_redirects">)
      assert_includes response.body, %(Turbo.visit("#{feed_monitor.sources_path}", options))
    end
  end
end
