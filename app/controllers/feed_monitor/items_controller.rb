# frozen_string_literal: true

module FeedMonitor
  class ItemsController < ApplicationController
    include ActionView::RecordIdentifier

    PER_PAGE = 25
    SEARCH_FIELD = :title_or_summary_or_url_or_source_name_cont

    before_action :set_item, only: %i[show scrape]
    before_action :load_scrape_context, only: :show

    def index
      base_scope = Item.includes(:source).recent
      @search_params = sanitized_search_params
      @q = base_scope.ransack(@search_params)
      @q.sorts = "published_at desc, created_at desc" if @q.sorts.blank?

      scope = @q.result(distinct: true)

      @page = params.fetch(:page, 1).to_i
      @page = 1 if @page < 1

      offset = (@page - 1) * PER_PAGE
      @items = scope.offset(offset).limit(PER_PAGE + 1)

      @has_next_page = @items.length > PER_PAGE
      @items = @items.first(PER_PAGE)
      @has_previous_page = @page > 1

      @search_term = @search_params[SEARCH_FIELD.to_s].to_s.strip
      @search_field = SEARCH_FIELD
    end

    def show
    end

    def scrape
      log_manual_scrape("controller:start", item: @item, extra: { format: request.format })

      enqueue_result = FeedMonitor::Scraping::Enqueuer.enqueue(item: @item, reason: :manual)
      log_manual_scrape(
        "controller:enqueue_result",
        item: @item,
        extra: { status: enqueue_result.status, message: enqueue_result.message }
      )
      flash_key, flash_message = scrape_flash_payload(enqueue_result)
      status = enqueue_result.failure? ? :unprocessable_entity : :ok

      respond_to do |format|
        format.turbo_stream do
          log_manual_scrape("controller:respond_turbo", item: @item, extra: { status: status })

          streams = []

          # Always update the item details if enqueue succeeded or was already enqueued
          if enqueue_result.enqueued? || enqueue_result.already_enqueued?
            streams << turbo_stream.replace(
              dom_id(@item, :details),
              partial: "feed_monitor/items/details_wrapper",
              locals: { item: @item.reload }
            )
          end

          # Add toast notification
          if flash_message
            level = flash_key == :notice ? :info : :error
            streams << turbo_stream.append(
              "feed_monitor_notifications",
              partial: "feed_monitor/shared/toast",
              locals: { message: flash_message, level: level, title: nil, delay_ms: 5000 }
            )
          end

          render turbo_stream: streams, status: status
        end

        format.html do
          log_manual_scrape("controller:respond_html", item: @item)
          if flash_key && flash_message
            redirect_to feed_monitor.item_path(@item), flash: { flash_key => flash_message }
          else
            redirect_to feed_monitor.item_path(@item)
          end
        end
      end
    end

    private

    def set_item
      @item = Item.includes(:source, :item_content).find(params[:id])
    end

    def load_scrape_context
      @recent_scrape_logs = @item.scrape_logs.order(started_at: :desc).limit(5)
      @latest_scrape_log = @recent_scrape_logs.first
    end

    def scrape_flash_payload(result)
      case result.status
      when :enqueued
        [:notice, "Scrape has been enqueued and will run shortly."]
      when :already_enqueued
        [:notice, result.message]
      else
        [:alert, result.message || "Unable to enqueue scrape for this item."]
      end
    end

    def log_manual_scrape(stage, item:, extra: {})
      return unless defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger

      payload = { stage:, item_id: item&.id }.merge(extra.compact)
      Rails.logger.info("[FeedMonitor::ManualScrape] #{payload.to_json}")
    rescue StandardError
      nil
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
  end
end
