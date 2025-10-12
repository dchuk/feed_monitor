module FeedMonitor
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception, prepend: true

    before_action :authenticate_feed_monitor_user
    before_action :authorize_feed_monitor_access

    helper_method :feed_monitor_current_user, :feed_monitor_user_signed_in?
    after_action :broadcast_flash_toasts

    private

    FLASH_LEVELS = {
      notice: :success,
      alert: :error,
      error: :error,
      success: :success,
      warning: :warning
    }.freeze

    def authenticate_feed_monitor_user
      FeedMonitor::Security::Authentication.authenticate!(self)
    end

    def authorize_feed_monitor_access
      FeedMonitor::Security::Authentication.authorize!(self)
    end

    def feed_monitor_current_user
      FeedMonitor::Security::Authentication.current_user(self)
    end

    def feed_monitor_user_signed_in?
      FeedMonitor::Security::Authentication.user_signed_in?(self)
    end

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
