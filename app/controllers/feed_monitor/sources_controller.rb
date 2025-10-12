# frozen_string_literal: true

module FeedMonitor
  class SourcesController < ApplicationController
    include ActionView::RecordIdentifier

    before_action :set_source, only: %i[show edit update destroy fetch retry]

    SEARCH_FIELD = :name_or_feed_url_or_website_url_cont

    def index
      base_scope = Source.all
      @search_params = sanitized_search_params
      @q = base_scope.ransack(@search_params)
      @q.sorts = ["created_at desc"] if @q.sorts.blank?

      @sources = @q.result

      @search_term = @search_params[SEARCH_FIELD.to_s].to_s.strip
      @search_field = SEARCH_FIELD
      @fetch_interval_filter = extract_fetch_interval_filter(@search_params)

      distribution_scope = distribution_sources_scope(base_scope)
      @fetch_interval_distribution = FeedMonitor::Analytics::SourceFetchIntervalDistribution.new(scope: distribution_scope).buckets
      @selected_fetch_interval_bucket = find_matching_bucket(@fetch_interval_filter, @fetch_interval_distribution)
      @item_activity_rates = FeedMonitor::Analytics::SourceActivityRates.new(scope: @sources).per_source_rates
    end

    def show
      @recent_fetch_logs = @source.fetch_logs.order(started_at: :desc).limit(5)
      @recent_scrape_logs = @source.scrape_logs.order(started_at: :desc).limit(5)
      @items = @source.items.recent.limit(10)
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
      @source.destroy
      redirect_to feed_monitor.sources_path, notice: "Source deleted"
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
          render turbo_stream: turbo_stream.append(
            "feed_monitor_notifications",
            partial: "feed_monitor/shared/toast",
            locals: { message: error_message, level: :error, title: nil, delay_ms: 6000 }
          ), status: :unprocessable_entity
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
          render turbo_stream: [
            turbo_stream.replace(
              dom_id(refreshed, :details),
              partial: "feed_monitor/sources/details_wrapper",
              locals: { source: refreshed }
            ),
            turbo_stream.replace(
              dom_id(refreshed, :row),
              partial: "feed_monitor/sources/row",
              locals: {
                source: refreshed,
                item_activity_rates: { refreshed.id => FeedMonitor::Analytics::SourceActivityRates.rate_for(refreshed) }
              }
            ),
            turbo_stream.append(
              "feed_monitor_notifications",
              partial: "feed_monitor/shared/toast",
              locals: { message:, level: :info, title: nil, delay_ms: 5000 }
            )
          ]
        end

        format.html do
          redirect_to feed_monitor.source_path(refreshed), notice: message
        end
      end
    end

    def sanitized_search_params
      raw = params[:q]
      return {} unless raw

      hash =
        if raw.respond_to?(:to_unsafe_h)
          raw.to_unsafe_h
        elsif raw.respond_to?(:to_h)
          raw.to_h
        elsif raw.is_a?(Hash)
          raw
        else
          {}
        end

      sanitized = FeedMonitor::Security::ParameterSanitizer.sanitize(hash)

      sanitized.each_with_object({}) do |(key, value), memo|
        next if value.respond_to?(:blank?) ? value.blank? : value.nil?

        memo[key.to_s] = value
      end
    end

    def extract_fetch_interval_filter(search_params)
      min = integer_param(search_params["fetch_interval_minutes_gteq"])
      max = integer_param(search_params["fetch_interval_minutes_lt"]) || integer_param(search_params["fetch_interval_minutes_lteq"])

      return if min.nil? && max.nil?

      { min: min, max: max }
    end

    def integer_param(value)
      return if value.blank?

      Integer(value)
    rescue ArgumentError, TypeError
      nil
    end

    def distribution_sources_scope(base_scope)
      interval_keys = %w[fetch_interval_minutes_gteq fetch_interval_minutes_lt fetch_interval_minutes_lteq]
      distribution_params = @search_params.except(*interval_keys)
      base_scope.ransack(distribution_params).result
    end

    def find_matching_bucket(filter, buckets)
      return if filter.blank? || buckets.blank?

      buckets.find do |bucket|
        min_match = filter[:min].present? ? filter[:min].to_i == bucket.min.to_i : bucket.min.nil?
        max_match = if bucket.max.nil?
          filter[:max].nil?
        else
          filter[:max].present? && filter[:max].to_i == bucket.max.to_i
        end

        min_match && max_match
      end
    end
  end
end
