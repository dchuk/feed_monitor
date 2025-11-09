# frozen_string_literal: true

module Feedmon
  class SponsoredSource < Source
    store_accessor :metadata, :sponsor_name

    validates :sponsor_name, presence: true, if: :sponsored?

    def sponsored?
      sponsor_name.present?
    end
  end
end
