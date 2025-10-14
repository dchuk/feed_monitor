# frozen_string_literal: true

require "feed_monitor/sources/turbo_stream_presenter"
require "feed_monitor/scraping/bulk_result_presenter"

module FeedMonitor
  class SourcesController < ApplicationController
    include ActionView::RecordIdentifier
    include FeedMonitor::SanitizesSearchParams

    searchable_with scope: -> { Source.all }, default_sorts: ["created_at desc"]

    ITEMS_PREVIEW_LIMIT = FeedMonitor::Scraping::BulkSourceScraper::DEFAULT_PREVIEW_LIMIT

    before_action :set_source, only: %i[show edit update destroy]

    SEARCH_FIELD = :name_or_feed_url_or_website_url_cont

    def index
      @search_params = sanitized_search_params
      @q = build_search_query

      @sources = @q.result

      @search_term = @search_params[SEARCH_FIELD.to_s].to_s.strip
      @search_field = SEARCH_FIELD

      metrics = FeedMonitor::Analytics::SourcesIndexMetrics.new(
        base_scope: Source.all,
        result_scope: @sources,
        search_params: @search_params
      )

      @fetch_interval_distribution = metrics.fetch_interval_distribution
      @fetch_interval_filter = metrics.fetch_interval_filter
      @selected_fetch_interval_bucket = metrics.selected_fetch_interval_bucket
      @item_activity_rates = metrics.item_activity_rates
    end

    def show
      @recent_fetch_logs = @source.fetch_logs.order(started_at: :desc).limit(5)
      @recent_scrape_logs = @source.scrape_logs.order(started_at: :desc).limit(5)
      @items = @source.items.recent.limit(ITEMS_PREVIEW_LIMIT)
      @bulk_scrape_selection = :current
    end

    def new
      @source = Source.new(default_attributes)
    end

    def create
      @source = Source.new(source_params)

      if @source.save
        redirect_to feed_monitor.source_path(@source), notice: "Source created successfully"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @source.update(source_params)
        redirect_to feed_monitor.source_path(@source), notice: "Source updated successfully"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      search_params = sanitized_search_params
      @source.destroy
      message = "Source deleted"

      respond_to do |format|
        format.turbo_stream do
          query = build_search_query(params: search_params)

          metrics = FeedMonitor::Analytics::SourcesIndexMetrics.new(
            base_scope: Source.all,
            result_scope: query.result,
            search_params:
          )

          redirect_location = safe_redirect_path(params[:redirect_to])

          responder = FeedMonitor::TurboStreams::StreamResponder.new
          presenter = FeedMonitor::Sources::TurboStreamPresenter.new(source: @source, responder:)

          presenter.render_deletion(
            metrics:,
            query:,
            search_params:,
            redirect_location:
          )

          responder.toast(message:, level: :success)

          render turbo_stream: responder.render(view_context)
        end

        format.html do
          redirect_to feed_monitor.sources_path, notice: message
        end
      end
    end

    def fetch
      FeedMonitor::Fetching::FetchRunner.enqueue(@source.id)
      render_fetch_enqueue_response("Fetch has been enqueued and will run shortly.")
    rescue StandardError => error
      handle_fetch_failure(error)
    end

    def retry
      FeedMonitor::Fetching::FetchRunner.enqueue(@source.id, force: true)
      render_fetch_enqueue_response("Retry has been forced and will run shortly.")
    rescue StandardError => error
      handle_fetch_failure(error)
    end

    private

    def set_source
      @source = Source.find(params[:id])
    end

    def default_attributes
      {
        active: true,
        scraping_enabled: false,
        auto_scrape: false,
        requires_javascript: false,
        feed_content_readability_enabled: false,
        fetch_interval_minutes: 360,
        adaptive_fetching_enabled: true,
        scraper_adapter: "readability"
      }
    end

    def source_params
      permitted = params.require(:source).permit(
        :name,
        :feed_url,
        :website_url,
        :fetch_interval_minutes,
        :active,
        :auto_scrape,
        :scraping_enabled,
        :requires_javascript,
        :feed_content_readability_enabled,
        :scraper_adapter,
        :items_retention_days,
        :max_items,
        :adaptive_fetching_enabled,
        :health_auto_pause_threshold,
        scrape_settings: [
          :include_plain_text,
          :timeout,
          :javascript_enabled,
          { selectors: %i[content title],
            http: [],
            readability: [] }
        ]
      )

      FeedMonitor::Security::ParameterSanitizer.sanitize(permitted.to_h)
    end

    def safe_redirect_path(raw_value)
      return if raw_value.blank?

      sanitized = FeedMonitor::Security::ParameterSanitizer.sanitize(raw_value.to_s)
      sanitized.start_with?("/") ? sanitized : nil
    end
  end
end
