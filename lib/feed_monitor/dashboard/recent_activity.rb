# frozen_string_literal: true

module FeedMonitor
  module Dashboard
    module RecentActivity
      Event = Struct.new(
        :type,
        :id,
        :occurred_at,
        :success,
        :items_created,
        :items_updated,
        :scraper_adapter,
        :item_title,
        :item_url,
        :source_name,
        :source_id,
        keyword_init: true
      ) do
        def type
          self[:type]&.to_sym
        end

        def success?
          !!self[:success]
        end
      end
    end
  end
end
