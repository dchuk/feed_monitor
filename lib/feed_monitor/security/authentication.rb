# frozen_string_literal: true

module FeedMonitor
  module Security
    module Authentication
      module_function

      def authenticate!(controller)
        call_handler(settings.authenticate_handler, controller)
      end

      def authorize!(controller)
        call_handler(settings.authorize_handler, controller)
      end

      def current_user(controller)
        method_name = preferred_current_user_method(controller)
        safe_public_send(controller, method_name)
      end

      def user_signed_in?(controller)
        method_name = preferred_user_signed_in_method(controller)

        if method_name
          safe_public_send(controller, method_name)
        else
          !!current_user(controller)
        end
      end

      def authentication_configured?
        settings.authenticate_handler.present? || settings.authorize_handler.present?
      end

      def authorize_configured?
        settings.authorize_handler.present?
      end

      def authenticate_configured?
        settings.authenticate_handler.present?
      end

      private

      def settings
        FeedMonitor.config.authentication
      end

      def call_handler(handler, controller)
        return unless handler

        handler.call(controller)
      end

      def safe_public_send(controller, method_name)
        return unless method_name
        return unless controller.respond_to?(method_name, true)

        controller.public_send(method_name)
      end

      def preferred_current_user_method(controller)
        method_name = settings.current_user_method
        method_name = method_name.to_sym if method_name.respond_to?(:to_sym)

        if method_name
          method_name
        elsif controller.respond_to?(:current_user, true)
          :current_user
        end
      end

      def preferred_user_signed_in_method(controller)
        method_name = settings.user_signed_in_method
        method_name = method_name.to_sym if method_name.respond_to?(:to_sym)

        if method_name
          method_name
        elsif controller.respond_to?(:user_signed_in?, true)
          :user_signed_in?
        end
      end
    end
  end
end
