# frozen_string_literal: true

module FeedMonitor
  class ItemsController < ApplicationController
    PER_PAGE = 25

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
      @item = Item.includes(:source, :item_content).find(params[:id])
    end
  end
end
