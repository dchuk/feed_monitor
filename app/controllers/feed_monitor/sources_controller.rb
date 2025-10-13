# frozen_string_literal: true

module FeedMonitor
  class SourcesController < ApplicationController
    include ActionView::RecordIdentifier
    include FeedMonitor::SanitizesSearchParams

    ITEMS_PREVIEW_LIMIT = FeedMonitor::Scraping::BulkSourceScraper::DEFAULT_PREVIEW_LIMIT

    before_action :set_source, only: %i[show edit update destroy fetch retry scrape_all]

    SEARCH_FIELD = :name_or_feed_url_or_website_url_cont

    def index
      base_scope = Source.all
      @search_params = sanitized_search_params
      @q = base_scope.ransack(@search_params)
      @q.sorts = [ "created_at desc" ] if @q.sorts.blank?

      @sources = @q.result

      @search_term = @search_params[SEARCH_FIELD.to_s].to_s.strip
      @search_field = SEARCH_FIELD

      metrics = FeedMonitor::Analytics::SourcesIndexMetrics.new(
        base_scope:,
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

    def scrape_all
      selection = scrape_all_params[:selection]
      normalized_selection = FeedMonitor::Scraping::BulkSourceScraper.normalize_selection(selection) || :current
      @bulk_scrape_selection = normalized_selection

      result = FeedMonitor::Scraping::BulkSourceScraper.new(
        source: @source,
        selection: normalized_selection,
        preview_limit: ITEMS_PREVIEW_LIMIT
      ).call

      respond_to_bulk_scrape(result)
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
          base_scope = Source.all
          query = base_scope.ransack(search_params)
          query.sorts = [ "created_at desc" ] if query.sorts.blank?
          sources = query.result

          metrics = FeedMonitor::Analytics::SourcesIndexMetrics.new(
            base_scope:,
            result_scope: sources,
            search_params:
          )

          redirect_location = safe_redirect_path(params[:redirect_to])

          responder = FeedMonitor::TurboStreams::StreamResponder.new
          responder.remove_row(@source)
          responder.remove("feed_monitor_sources_empty_state")
          responder.replace(
            "feed_monitor_sources_heatmap",
            partial: "feed_monitor/sources/fetch_interval_heatmap",
            locals: {
              fetch_interval_distribution: metrics.fetch_interval_distribution,
              selected_bucket: metrics.selected_fetch_interval_bucket,
              search_params:
            }
          )

          unless sources.exists?
            responder.append(
              "feed_monitor_sources_table_body",
              partial: "feed_monitor/sources/empty_state_row"
            )
          end

          if redirect_location
            responder.append(
              "feed_monitor_redirects",
              partial: "feed_monitor/shared/turbo_visit",
              locals: {
                url: redirect_location,
                action: "replace"
              }
            )
          end

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

    def handle_fetch_failure(error)
      error_message = "Fetch could not be enqueued: #{error.message}"

      respond_to do |format|
        format.turbo_stream do
          responder = FeedMonitor::TurboStreams::StreamResponder.new
          responder.toast(message: error_message, level: :error, delay_ms: 6000)

          render turbo_stream: responder.render(view_context), status: :unprocessable_entity
        end

        format.html do
          redirect_to feed_monitor.source_path(@source), alert: error_message
        end
      end
    end

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
          { selectors: %i[content title] }
        ]
      )

      FeedMonitor::Security::ParameterSanitizer.sanitize(permitted.to_h)
    end

    def render_fetch_enqueue_response(message)
      refreshed = @source.reload
      respond_to do |format|
        format.turbo_stream do
          responder = FeedMonitor::TurboStreams::StreamResponder.new

          responder.replace_details(
            refreshed,
            partial: "feed_monitor/sources/details_wrapper",
            locals: { source: refreshed }
          )

          responder.replace_row(
            refreshed,
            partial: "feed_monitor/sources/row",
            locals: {
              source: refreshed,
              item_activity_rates: { refreshed.id => FeedMonitor::Analytics::SourceActivityRates.rate_for(refreshed) }
            }
          )

          responder.toast(message:, level: :info, delay_ms: 5000)

          render turbo_stream: responder.render(view_context)
        end

        format.html do
          redirect_to feed_monitor.source_path(refreshed), notice: message
        end
      end
    end

    def respond_to_bulk_scrape(result)
      refreshed = @source.reload
      @bulk_scrape_selection = result.selection
      payload = bulk_scrape_flash_payload(result)
      status = result.error? ? :unprocessable_entity : :ok

      respond_to do |format|
        format.turbo_stream do
          responder = FeedMonitor::TurboStreams::StreamResponder.new

          responder.replace_details(
            refreshed,
            partial: "feed_monitor/sources/details_wrapper",
            locals: { source: refreshed }
          )

          responder.replace_row(
            refreshed,
            partial: "feed_monitor/sources/row",
            locals: {
              source: refreshed,
              item_activity_rates: { refreshed.id => FeedMonitor::Analytics::SourceActivityRates.rate_for(refreshed) }
            }
          )

          if payload[:message].present?
            responder.toast(
              message: payload[:message],
              level: payload[:level],
              delay_ms: 6000
            )
          end

          render turbo_stream: responder.render(view_context), status: status
        end

        format.html do
          if payload[:message].present?
            redirect_to feed_monitor.source_path(refreshed), flash: { payload[:flash_key] => payload[:message] }
          else
            redirect_to feed_monitor.source_path(refreshed)
          end
        end
      end
    end

    def bulk_scrape_flash_payload(result)
      label = FeedMonitor::Scraping::BulkSourceScraper.selection_label(result.selection)
      pluralized_enqueued = view_context.pluralize(result.enqueued_count, "item")
      pluralized_already = view_context.pluralize(result.already_enqueued_count, "item")

      case result.status
      when :success
        message = "Queued scraping for #{pluralized_enqueued} from the #{label}."
        if result.already_enqueued_count.positive?
          message = "#{message} #{pluralized_already.capitalize} already in progress."
        end

        { flash_key: :notice, message:, level: :success }
      when :partial
        parts = []
        if result.enqueued_count.positive?
          parts << "Queued #{pluralized_enqueued} from the #{label}"
        end

        if result.already_enqueued_count.positive?
          parts << "#{pluralized_already.capitalize} already in progress"
        end

        if result.rate_limited?
          limit = FeedMonitor.config.scraping.max_in_flight_per_source
          parts << "Stopped after reaching the per-source limit#{" of #{limit}" if limit}"
        end

        other_failures = result.failure_details.except(:rate_limited)
        if other_failures.values.sum.positive?
          skipped = other_failures.map do |status, count|
            label_key = status.to_s.tr("_", " ")
            "#{view_context.pluralize(count, label_key)}"
          end.join(", ")
          parts << "Skipped #{skipped}"
        end

        if parts.empty?
          parts << "No new scrapes were queued from the #{label}"
        end

        { flash_key: :notice, message: parts.join(". ") + ".", level: :warning }
      else
        message = result.messages.presence&.first || "No items were queued because nothing matched the selected scope."
        { flash_key: :alert, message:, level: :error }
      end
    end

    def scrape_all_params
      params.fetch(:bulk_scrape, {}).permit(:selection)
    end

    def safe_redirect_path(raw_value)
      return if raw_value.blank?

      sanitized = FeedMonitor::Security::ParameterSanitizer.sanitize(raw_value.to_s)
      sanitized.start_with?("/") ? sanitized : nil
    end
  end
end
