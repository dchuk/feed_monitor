# frozen_string_literal: true

module Feedmon
  module Loggable
    extend ActiveSupport::Concern

    included do
      attribute :metadata, default: -> { {} }

      validates :started_at, presence: true
      validates :duration_ms, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

      scope :recent, -> { order(started_at: :desc) }
      scope :successful, -> { where(success: true) }
      scope :failed, -> { where(success: false) }
    end
  end
end
