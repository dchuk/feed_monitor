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
      enqueue_result = FeedMonitor::Scraping::Enqueuer.enqueue(item: @item, reason: :manual)

      case enqueue_result.status
      when :enqueued
        flash[:notice] = "Scrape has been enqueued and will run shortly."
      when :already_enqueued
        flash[:notice] = enqueue_result.message
      else
        flash[:alert] = enqueue_result.message || "Unable to enqueue scrape for this item."
      end

      redirect_to feed_monitor.item_path(@item)
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
