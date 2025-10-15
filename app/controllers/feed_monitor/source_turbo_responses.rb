# frozen_string_literal: true

module FeedMonitor
  module SourceTurboResponses
    extend ActiveSupport::Concern

    included do
      include ActionView::RecordIdentifier
    end

    private

    def render_fetch_enqueue_response(message)
      @source.reload
      respond_to do |format|
        format.turbo_stream do
          responder = FeedMonitor::TurboStreams::StreamResponder.new

          responder.replace_details(
            @source,
            partial: "feed_monitor/sources/details_wrapper",
            locals: { source: @source }
          )

          responder.replace_row(
            @source,
            partial: "feed_monitor/sources/row",
            locals: {
              source: @source,
              item_activity_rates: { @source.id => FeedMonitor::Analytics::SourceActivityRates.rate_for(@source) }
            }
          )

          responder.toast(message:, level: :info, delay_ms: toast_delay_for(:info))

          render turbo_stream: responder.render(view_context)
        end

        format.html do
          redirect_to feed_monitor.source_path(@source), notice: message
        end
      end
    end

    def handle_fetch_failure(error)
      error_message = "Fetch could not be enqueued: #{error.message}"

      respond_to do |format|
        format.turbo_stream do
          responder = FeedMonitor::TurboStreams::StreamResponder.new
          responder.toast(message: error_message, level: :error, delay_ms: toast_delay_for(:error))

          render turbo_stream: responder.render(view_context), status: :unprocessable_entity
        end

        format.html do
          redirect_to feed_monitor.source_path(@source), alert: error_message
        end
      end
    end

    def respond_to_bulk_scrape(result)
      @source.reload
      @bulk_scrape_selection = result.selection
      payload = bulk_scrape_flash_payload(result)
      status = result.error? ? :unprocessable_entity : :ok

      respond_to do |format|
        format.turbo_stream do
          responder = FeedMonitor::TurboStreams::StreamResponder.new

          responder.replace_details(
            @source,
            partial: "feed_monitor/sources/details_wrapper",
            locals: { source: @source }
          )

          responder.replace_row(
            @source,
            partial: "feed_monitor/sources/row",
            locals: {
              source: @source,
              item_activity_rates: { @source.id => FeedMonitor::Analytics::SourceActivityRates.rate_for(@source) }
            }
          )

          if payload[:message].present?
            responder.toast(
              message: payload[:message],
              level: payload[:level],
              delay_ms: toast_delay_for(payload[:level])
            )
          end

          render turbo_stream: responder.render(view_context), status: status
        end

        format.html do
          if payload[:message].present?
            redirect_to feed_monitor.source_path(@source), flash: { payload[:flash_key] => payload[:message] }
          else
            redirect_to feed_monitor.source_path(@source)
          end
        end
      end
    end

    def bulk_scrape_flash_payload(result)
      pluralizer = ->(count, word) { view_context.pluralize(count, word) }
      presenter = FeedMonitor::Scraping::BulkResultPresenter.new(result:, pluralizer:)
      presenter.to_flash_payload
    end
  end
end
