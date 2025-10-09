# frozen_string_literal: true

require "application_system_test_case"

module FeedMonitor
  class MissionControlTest < ApplicationSystemTestCase
    test "mission control renders in light theme with queues tab" do
      page.driver.browser.basic_authorize("feedmonitor", "change-me")

      visit "/mission_control"

      assert_selector "html[data-theme='light']"
      assert_selector "body.theme-light"
      assert_text "Queues"
      assert_text "Failed jobs"
    end
  end
end
