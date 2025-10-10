# frozen_string_literal: true

module FeedMonitor
  class SourcesController < ApplicationController
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
      FeedMonitor::Fetching::FetchRunner.enqueue(@source.id)
      redirect_to feed_monitor.source_path(@source), notice: "Fetch has been enqueued and will run shortly."
    rescue StandardError => error
      redirect_to feed_monitor.source_path(@source), alert: "Fetch could not be enqueued: #{error.message}"
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
        scrape_settings: [
          { selectors: %i[content title] }
        ]
      )
    end
  end
end
