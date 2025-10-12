# frozen_string_literal: true

module FeedMonitor
  module SanitizesSearchParams
    extend ActiveSupport::Concern

    private

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

      sanitized_params = sanitized.each_with_object({}) do |(key, value), memo|
        next if value.nil?

        cleaned_value = value.is_a?(String) ? value.strip : value
        next if cleaned_value.respond_to?(:blank?) ? cleaned_value.blank? : cleaned_value.nil?

        memo[key.to_s] = cleaned_value
      end

      assign_sanitized_params(sanitized_params)

      sanitized_params
    end

    def assign_sanitized_params(sanitized_params)
      return unless respond_to?(:params) && params

      if params.is_a?(ActionController::Parameters)
        params[:q] = ActionController::Parameters.new(sanitized_params)
      else
        params[:q] = sanitized_params
      end
    end
  end
end
