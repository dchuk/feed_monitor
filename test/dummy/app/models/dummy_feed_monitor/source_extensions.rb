# frozen_string_literal: true

module DummyFeedMonitor
  module SourceExtensions
    extend ActiveSupport::Concern

    included do
      store_accessor :metadata, :testing_notes
    end

    def testing_notes?
      testing_notes.present?
    end

    def enforce_testing_notes_length
      return unless testing_notes?
      return if testing_notes.length <= 280

      errors.add(:metadata, "testing_notes must be 280 characters or fewer")
    end
  end
end
