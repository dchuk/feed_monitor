require "test_helper"

module FeedMonitor
  class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
    driven_by :rack_test
  end
end
