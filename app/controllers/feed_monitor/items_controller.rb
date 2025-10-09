# frozen_string_literal: true

module FeedMonitor
  class ItemsController < ApplicationController
    PER_PAGE = 25

    before_action :set_item, only: %i[show scrape]
    before_action :load_scrape_context, only: :show

    def index
      @search = params[:search].to_s.strip
      @page = params.fetch(:page, 1).to_i
      @page = 1 if @page < 1

      scope = Item.includes(:source).recent

      if @search.present?
        term = ActiveRecord::Base.sanitize_sql_like(@search)
        scope = scope.where("title ILIKE ?", "%#{term}%")
      end

      offset = (@page - 1) * PER_PAGE
      @items = scope.offset(offset).limit(PER_PAGE + 1)

      @has_next_page = @items.length > PER_PAGE
      @items = @items.first(PER_PAGE)
      @has_previous_page = @page > 1
    end

    def show
    end

    def scrape
      unless @item.source&.scraping_enabled?
        redirect_to feed_monitor.item_path(@item), alert: "Scraping is disabled for this source."
        return
      end

      result = FeedMonitor::Scraping::ItemScraper.new(item: @item).call
      @item.reload

      flash[result.success? ? :notice : :alert] = result.message
      redirect_to feed_monitor.item_path(@item)
    rescue FeedMonitor::Scraping::ItemScraper::UnknownAdapterError => error
      redirect_to feed_monitor.item_path(@item), alert: "Scrape failed: #{error.message}"
    end

    private

    def set_item
      @item = Item.includes(:source, :item_content).find(params[:id])
    end

    def load_scrape_context
      @recent_scrape_logs = @item.scrape_logs.order(started_at: :desc).limit(5)
      @latest_scrape_log = @recent_scrape_logs.first
    end
  end
end
