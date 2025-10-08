# frozen_string_literal: true

module FeedMonitor
  class SourcesController < ApplicationController
    before_action :set_source, only: %i[show edit update destroy fetch]

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

    def fetch
      result = FeedMonitor::Fetching::FeedFetcher.new(source: @source).call
      case result.status
      when :fetched
        processing = result.item_processing
        message = build_fetch_summary(processing)
        redirect_to feed_monitor.source_path(@source), notice: message
      when :not_modified
        redirect_to feed_monitor.source_path(@source), notice: "Source is already up to date"
      else
        message = result.error&.message || "Unknown error"
        redirect_to feed_monitor.source_path(@source), alert: "Fetch failed: #{message}"
      end
    rescue StandardError => error
      redirect_to feed_monitor.source_path(@source), alert: "Fetch failed: #{error.message}"
    end

    private

    def set_source
      @source = Source.find(params[:id])
    end

    def build_fetch_summary(processing)
      created = processing&.created.to_i
      updated = processing&.updated.to_i
      failed = processing&.failed.to_i

      parts = []
      parts << pluralize_count(created, "item created", "items created") if created.positive?
      parts << pluralize_count(updated, "item updated", "items updated") if updated.positive?
      parts << pluralize_count(failed, "item failed", "items failed") if failed.positive?

      summary = parts.presence || ["no changes"]
      "Fetch completed: #{summary.join(', ')}."
    end

    def pluralize_count(count, singular, plural)
      view_context.pluralize(count, singular, plural)
    end

    def default_attributes
      {
        active: true,
        scraping_enabled: false,
        auto_scrape: false,
        requires_javascript: false,
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
        :scraper_adapter,
        :items_retention_days,
        :max_items
      )
    end
  end
end
