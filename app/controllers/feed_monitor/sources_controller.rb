# frozen_string_literal: true

module FeedMonitor
  class SourcesController < ApplicationController
    def new
      @source = Source.new(
        active: true,
        scraping_enabled: false,
        auto_scrape: false,
        requires_javascript: false,
        fetch_interval_hours: 6,
        scraper_adapter: "readability"
      )
    end

    def create
      @source = Source.new(source_params)

      if @source.save
        redirect_to root_path, notice: "Source created successfully"
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

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
        :scraper_adapter
      )
    end
  end
end
