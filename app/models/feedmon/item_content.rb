# frozen_string_literal: true

module Feedmon
  class ItemContent < ApplicationRecord
    belongs_to :item, class_name: "Feedmon::Item", inverse_of: :item_content, touch: true

    validates :item, presence: true

    Feedmon::ModelExtensions.register(self, :item_content)
  end
end
