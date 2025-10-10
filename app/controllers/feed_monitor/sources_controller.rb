# frozen_string_literal: true

module FeedMonitor
  class SourcesController < ApplicationController
    include ActionView::RecordIdentifier

    before_action :set_source, only: %i[show edit update destroy fetch]

    def index
      @sources = Source.order(created_at: :desc)
      @fetch_interval_distribution = FeedMonitor::Analytics::SourceFetchIntervalDistribution.new(scope: @sources).buckets
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
      # Update source status optimistically before enqueueing
      @source.update!(fetch_status: "queued")
      FeedMonitor::Fetching::FetchRunner.enqueue(@source.id)
      success_message = "Fetch has been enqueued and will run shortly."

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(
              dom_id(@source, :details),
              partial: "feed_monitor/sources/details_wrapper",
              locals: { source: @source.reload }
            ),
            turbo_stream.replace(
              dom_id(@source, :row),
              partial: "feed_monitor/sources/row",
              locals: {
                source: @source,
                item_activity_rates: { @source.id => FeedMonitor::Analytics::SourceActivityRates.rate_for(@source) }
              }
            ),
            turbo_stream.append(
              "feed_monitor_notifications",
              partial: "feed_monitor/shared/toast",
              locals: { message: success_message, level: :info, title: nil, delay_ms: 5000 }
            )
          ]
        end

        format.html do
          redirect_to feed_monitor.source_path(@source), notice: success_message
        end
      end
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
      params.require(:source).permit(
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
        scrape_settings: [
          { selectors: %i[content title] }
        ]
      )
    end
  end
end
