# frozen_string_literal: true

module FeedMonitor
  class SourcesController < ApplicationController
    before_action :set_source, only: %i[show edit update destroy]

    def index
      @sources = Source.order(created_at: :desc)
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
        fetch_interval_hours: 6,
        scraper_adapter: "readability"
      }
    end

    def source_params
      params.require(:source).permit(
        :name,
        :feed_url,
        :website_url,
        :fetch_interval_hours,
        :active,
        :auto_scrape,
        :scraping_enabled,
        :requires_javascript,
        :scraper_adapter,
        :items_retention_days,
        :max_items
      )
    end
  end
end
