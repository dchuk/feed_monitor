module FeedMonitor
  class ApplicationController < ActionController::Base
    after_action :broadcast_flash_toasts

    private

    FLASH_LEVELS = {
      notice: :success,
      alert: :error,
      error: :error,
      success: :success,
      warning: :warning
    }.freeze

    def broadcast_flash_toasts
      return if flash.empty?
      return unless request.format.html? || request.format.turbo_stream?

      flash.each do |key, message|
        next if message.blank?

        Array(message).each do |msg|
          FeedMonitor::Realtime.broadcast_toast(
            message: msg,
            level: FLASH_LEVELS[key.to_sym] || :info
          )
        end
      end
    ensure
      flash.discard
    end
  end
end
