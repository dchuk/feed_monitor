# frozen_string_literal: true

require "test_helper"
require "active_job/test_helper"
require "uri"

module FeedMonitor
  class OpmlImportsControllerTest < ActionDispatch::IntegrationTest
    include ActiveJob::TestHelper

    setup do
      FeedMonitor::OpmlImportsController.state_store.clear
      @progress_tokens = []
    end

    teardown do
      @progress_tokens.each do |token|
        FeedMonitor::Importing::OpmlImportProgress.reset!(token)
      end
      clear_enqueued_jobs
    end
    test "uploading an OPML file renders preview turbo stream" do
      existing = create_source!(
        name: "Existing Example",
        feed_url: "https://example.com/feed.xml",
        items_count: 7,
        fetch_status: "fetching"
      )

      outline = FeedMonitor::OPML::Outline.new(
        name: "Example Feed",
        feed_url: "https://example.com/feed.xml",
        website_url: "https://example.com/",
        feed_type: "rss",
        categories: ["Technology"]
      )
      parser_result = FeedMonitor::OPML::Parser::Result.new(
        version: "2.0",
        outlines: [outline],
        errors: []
      )

      FeedMonitor::OPML::Parser.stub(:call, parser_result) do
        post feed_monitor.opml_imports_path,
          params: {
            opml_import: {
              file: fixture_file_upload("files/opml/import_happy_path.opml", "application/xml")
            }
          },
          as: :turbo_stream
      end

      assert_response :success
      assert_equal "text/vnd.turbo-stream.html", response.media_type
      assert_includes response.body, "Preview Sources"
      assert_includes response.body, "data-testid=\"opml-import-preview-table\""
      assert_includes response.body, "Example Feed"
      assert_includes response.body, "data-testid=\"duplicate-indicator\""
      assert_includes response.body, "Current status: fetching"
    end

    test "start enqueues import jobs and seeds progress state" do
      ActiveJob::Base.queue_adapter = :test

      outlines = [
        FeedMonitor::OPML::Outline.new(
          name: "New Feed",
          feed_url: "https://new.example.com/feed.xml",
          website_url: "https://new.example.com/",
          categories: ["Tech"]
        )
      ]

      parser_result = FeedMonitor::OPML::Parser::Result.new(
        version: "2.0",
        outlines: outlines,
        errors: []
      )

      FeedMonitor::OPML::Parser.stub(:call, parser_result) do
        post feed_monitor.opml_imports_path,
          params: {
            opml_import: { file: fixture_file_upload("files/opml/import_happy_path.opml", "application/xml") }
          },
          as: :turbo_stream
      end

      token = session[FeedMonitor::OpmlImportsController::SESSION_TOKEN_KEY]
      assert_not_nil token
      @progress_tokens << token

      FeedMonitor::Importing::OpmlImportProgress.reset!(token)
      clear_enqueued_jobs

      post feed_monitor.opml_import_start_path

      assert_redirected_to feed_monitor.opml_import_progress_path
      assert_equal 1, enqueued_jobs.count

      job = enqueued_jobs.last
      assert_equal FeedMonitor::OpmlImportJob, job[:job]
      assert_equal token, job[:args].first
      entry = job[:args].second
      assert_equal "https://new.example.com/feed.xml", entry["feed_url"]
      assert_equal "create", entry["decision"]

      progress = FeedMonitor::Importing::OpmlImportProgress.progress(token)
      assert_equal "in_progress", progress["status"]
      assert_equal ["https://new.example.com/feed.xml"], progress["ordered_results"].map { |result| result["feed_url"] }
      assert_equal %w[pending], progress["ordered_results"].map { |result| result["status"] }
    ensure
      clear_enqueued_jobs
    end

    test "progress renders tracker results" do
      outlines = [
        FeedMonitor::OPML::Outline.new(
          name: "Progress Feed",
          feed_url: "https://progress.example.com/feed.xml"
        )
      ]

      parser_result = FeedMonitor::OPML::Parser::Result.new(
        version: "2.0",
        outlines: outlines,
        errors: []
      )

      FeedMonitor::OPML::Parser.stub(:call, parser_result) do
        post feed_monitor.opml_imports_path,
          params: {
            opml_import: { file: fixture_file_upload("files/opml/import_happy_path.opml", "application/xml") }
          },
          as: :turbo_stream
      end

      token = session[FeedMonitor::OpmlImportsController::SESSION_TOKEN_KEY]
      assert_not_nil token
      @progress_tokens << token

      entry = {
        "feed_url" => "https://progress.example.com/feed.xml",
        "name" => "Progress Feed",
        "decision" => "create"
      }

      FeedMonitor::Importing::OpmlImportProgress.reset!(token)
      FeedMonitor::Importing::OpmlImportProgress.merge_expected_entries(token:, entries: [entry])

      source = create_source!(feed_url: entry["feed_url"], name: entry["name"])
      health = { "success" => true, "message" => "OK" }
      result = FeedMonitor::Importing::OpmlImportService::Result.new(status: :created, source:, health_check: health)
      FeedMonitor::Importing::OpmlImportProgress.record_result(token:, entry:, result:)

      get feed_monitor.opml_import_progress_path

      assert_response :success
      assert_includes response.body, "Progress Feed"
      assert_includes response.body, "Created"
      assert_includes response.body, "Import complete"
    end

    test "progress surfaces audit metadata" do
      user = Struct.new(:id, :name, :email, keyword_init: true).new(id: 42, name: "Avery Admin", email: "avery@example.com")

      outlines = [
        FeedMonitor::OPML::Outline.new(
          name: "Audit Feed",
          feed_url: "https://audit.example.com/feed.xml"
        )
      ]

      parser_result = FeedMonitor::OPML::Parser::Result.new(
        version: "2.0",
        outlines: outlines,
        errors: []
      )

      FeedMonitor::Security::Authentication.stub(:current_user, ->(_controller) { user }) do
        FeedMonitor::OPML::Parser.stub(:call, parser_result) do
          post feed_monitor.opml_imports_path,
            params: {
              opml_import: { file: fixture_file_upload("files/opml/import_happy_path.opml", "application/xml") }
            },
            as: :turbo_stream
        end
      end

      token = session[FeedMonitor::OpmlImportsController::SESSION_TOKEN_KEY]
      assert_not_nil token
      @progress_tokens << token

      entry = {
        "feed_url" => "https://audit.example.com/feed.xml",
        "name" => "Audit Feed",
        "decision" => "create"
      }

      FeedMonitor::Importing::OpmlImportProgress.merge_expected_entries(token:, entries: [entry])

      source = create_source!(feed_url: entry["feed_url"], name: entry["name"])
      health = { success: true, message: "Feed responded", log_id: 101 }
      result = FeedMonitor::Importing::OpmlImportService::Result.new(status: :created, source:, health_check: health)
      FeedMonitor::Importing::OpmlImportProgress.record_result(token:, entry:, result: result)

      get feed_monitor.opml_import_progress_path

      assert_response :success
      assert_includes response.body, "Avery Admin"
      assert_includes response.body, "avery@example.com"
      assert_includes response.body, "import_happy_path.opml"
      assert_includes response.body, "Feed responded"
    end

    def health_stub(success:, message: nil)
      { "success" => success, "message" => message }
    end

    test "confirm persists selection state" do
      outlines = [
        FeedMonitor::OPML::Outline.new(name: "Example Feed", feed_url: "https://example.com/feed.xml"),
        FeedMonitor::OPML::Outline.new(name: "JSON Feed", feed_url: "https://json.example.com/feed.json")
      ]

      parser_result = FeedMonitor::OPML::Parser::Result.new(
        version: "2.0",
        outlines: outlines,
        errors: []
      )

      FeedMonitor::OPML::Parser.stub(:call, parser_result) do
        post feed_monitor.opml_imports_path,
          params: {
            opml_import: {
              file: fixture_file_upload("files/opml/import_happy_path.opml", "application/xml")
            }
          },
          as: :turbo_stream
      end

      post feed_monitor.opml_import_confirm_path,
        params: {
          opml_import: {
            selection: ["https://example.com/feed.xml"]
          }
        }

      assert_response :success

      token = session[FeedMonitor::OpmlImportsController::SESSION_TOKEN_KEY]
      assert_not_nil token, "expected session to store wizard token"

      state = FeedMonitor::OpmlImportsController.state_store.read(FeedMonitor::OpmlImportsController.cache_key_for(token))
      stored_outlines = state.fetch("outlines")
      selected = stored_outlines.select { |outline| outline["selected"] }
      assert_equal ["https://example.com/feed.xml"], selected.map { |outline| outline["feed_url"] }
    end

    test "missing file returns validation error turbo stream" do
      post feed_monitor.opml_imports_path,
        params: { opml_import: { file: nil } },
        as: :turbo_stream

      assert_response :unprocessable_entity
      assert_equal "text/vnd.turbo-stream.html", response.media_type
      assert_includes response.body, "Please choose an OPML file to upload"
    end

    test "parser errors are surfaced in preview turbo frame" do
      parser_result = FeedMonitor::OPML::Parser::Result.new(
        version: "2.0",
        outlines: [],
        errors: [
          FeedMonitor::OPML::Parser::Error.new(
            code: :missing_feed_url,
            message: "Outline requires an xmlUrl attribute",
            outline_attributes: { "title" => "Broken Feed" }
          )
        ]
      )

      FeedMonitor::OPML::Parser.stub(:call, parser_result) do
        post feed_monitor.opml_imports_path,
          params: {
            opml_import: {
              file: fixture_file_upload("files/opml/import_malformed_missing_url.opml", "application/xml")
            }
          },
          as: :turbo_stream
      end

      assert_response :success
      assert_includes response.body, "Broken Feed"
      assert_includes response.body, "could not be parsed"
    end
  end

    def health_stub(success:, message: nil)
      Struct.new(:success?, :message, keyword_init: true).new(success?: success, message: message)
    end
end
