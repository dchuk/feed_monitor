# frozen_string_literal: true

require "application_system_test_case"

module FeedMonitor
  class OpmlImportsTest < ApplicationSystemTestCase
    include ActiveJob::TestHelper

    setup do
      ActiveJob::Base.queue_adapter = :test
      clear_enqueued_jobs
      FeedMonitor::OpmlImportsController.state_store.clear
    end

    teardown do
      clear_enqueued_jobs
    end

    test "importing sources from an OPML file via wizard flow" do
      user = Struct.new(:id, :name, :email, keyword_init: true).new(id: 7, name: "Morgan Operator", email: "morgan@example.com")

      existing_source = create_source!(
        name: "Existing Example",
        feed_url: "https://example.com/feed.xml",
        items_count: 5,
        fetch_status: "idle",
        last_fetched_at: 2.hours.ago
      )

      FeedMonitor::Security::Authentication.stub(:current_user, ->(_controller) { user }) do
        visit feed_monitor.sources_path
        click_link "Import Sources"

        assert_selector "h1", text: "Import Sources from OPML"
        attach_file "OPML file", file_fixture("files/opml/import_happy_path.opml")
        click_button "Upload and Preview"

        assert_current_path feed_monitor.opml_import_preview_path, ignore_query: true
        assert_selector "h2", text: "Preview Sources"
        assert_selector "[data-testid='opml-import-preview-table']"
        assert_selector "[data-testid='opml-import-row']", text: "Example Feed"

        within "[data-testid='opml-import-filters']" do
          assert_selector "button", text: /All/
          assert_selector "button", text: /Only New Sources/
          assert_selector "button", text: /Only Existing Sources/
        end

        within "[data-testid='opml-import-row'][data-feed-url='https://example.com/feed.xml']" do
          assert_selector "input[type='checkbox'][name*='selection']:checked"
          assert_selector "[data-testid='duplicate-indicator']", text: "Existing"
          assert_text "Current status: #{existing_source.fetch_status}"
        end

        click_button "Only New Sources"
        assert_no_selector "[data-testid='opml-import-row'][data-feed-url='https://example.com/feed.xml']"

        click_button "Only Existing Sources"
        assert_selector "[data-testid='opml-import-row'][data-feed-url='https://example.com/feed.xml']"
        assert_no_selector "[data-testid='opml-import-row'][data-feed-url='https://jsonfeed.example.com/feed.json']"

        click_button "All"

        within "[data-testid='opml-import-row'][data-feed-url='https://jsonfeed.example.com/feed.json']" do
          find("input[type='checkbox'][name='opml_import[selection][]'][value='https://jsonfeed.example.com/feed.json']").uncheck
        end

        click_button "Continue"

        assert_current_path feed_monitor.opml_import_confirm_path
        assert_selector "h2", text: "Confirm Import"
        assert_selector "[data-testid='opml-import-summary']"
        assert_text "2 sources selected"
        within "[data-testid='opml-import-summary']" do
          names = all("li span.font-medium").map(&:text)
          assert_equal names.sort, names
        end

        click_button "Back to Preview"
        assert_current_path feed_monitor.opml_import_preview_path, ignore_query: true

        within "[data-testid='opml-import-row'][data-feed-url='https://jsonfeed.example.com/feed.json']" do
          assert_no_selector "input[type='checkbox'][name*='selection']:checked"
        end

        click_button "Continue"

        assert_current_path feed_monitor.opml_import_confirm_path
        assert_text "2 sources selected"

        click_button "Start Import"

        assert_current_path feed_monitor.opml_import_progress_path
        assert_selector "[data-testid='opml-import-progress']"
        assert_equal 2, enqueued_jobs.count { |job| job[:job] == FeedMonitor::OpmlImportJob }

        health_outcome = Struct.new(:success?, :log, :error, keyword_init: true).new(success?: true, log: nil, error: nil)
        health_service = Struct.new(:outcome) do
          def call = outcome
        end

        FeedMonitor::Health::SourceHealthCheck.stub(:new, ->(**) { health_service.new(health_outcome) }) do
          perform_enqueued_jobs
        end

        visit feed_monitor.opml_import_progress_path

        assert_text "Import complete"
        assert_selector "[data-testid='opml-import-progress-result']", text: "Example Feed"
        assert_selector "[data-testid='opml-import-progress-result']", text: "World News"
        assert_selector "[data-testid='opml-import-audit']"
        within "[data-testid='opml-import-audit']" do
          assert_text "Morgan Operator"
          assert_text "morgan@example.com"
          assert_text "import_happy_path.opml"
        end

        click_link "View Sources"
        assert_current_path feed_monitor.sources_path
      end
    end
  end
end
