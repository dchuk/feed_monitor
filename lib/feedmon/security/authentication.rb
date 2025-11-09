# frozen_string_literal: true

module Feedmon
  module Security
    module Authentication
      def self.authenticate!(controller)
        call_handler(Feedmon.config.authentication.authenticate_handler, controller)
      end

      def self.authorize!(controller)
        call_handler(Feedmon.config.authentication.authorize_handler, controller)
      end

      def self.current_user(controller)
        method_name = preferred_current_user_method(controller)
        safe_public_send(controller, method_name)
      end

      def self.user_signed_in?(controller)
        method_name = preferred_user_signed_in_method(controller)

        if method_name
          safe_public_send(controller, method_name)
        else
          !!current_user(controller)
        end
      end

      def self.authentication_configured?
        config = Feedmon.config.authentication
        config.authenticate_handler.present? || config.authorize_handler.present?
      end

      def self.authorize_configured?
        Feedmon.config.authentication.authorize_handler.present?
      end

      def self.authenticate_configured?
        Feedmon.config.authentication.authenticate_handler.present?
      end

      def self.call_handler(handler, controller)
        return unless handler

        handler.call(controller)
      end

      def self.safe_public_send(controller, method_name)
        return unless method_name
        return unless controller.respond_to?(method_name, true)

        controller.public_send(method_name)
      end

      def self.preferred_current_user_method(controller)
        config = Feedmon.config.authentication
        method_name = config.current_user_method
        method_name = method_name.to_sym if method_name.respond_to?(:to_sym)

        if method_name
          method_name
        elsif controller.respond_to?(:current_user, true)
          :current_user
        end
      end

      def self.preferred_user_signed_in_method(controller)
        config = Feedmon.config.authentication
        method_name = config.user_signed_in_method
        method_name = method_name.to_sym if method_name.respond_to?(:to_sym)

        if method_name
          method_name
        elsif controller.respond_to?(:user_signed_in?, true)
          :user_signed_in?
        end
      end

      private_class_method :call_handler,
        :safe_public_send,
        :preferred_current_user_method,
        :preferred_user_signed_in_method
    end
  end
end
