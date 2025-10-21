# frozen_string_literal: true

require "test_helper"

module FeedMonitor
  class ApplicationMailerTest < ActiveSupport::TestCase
    test "inherits from ActionMailer::Base with default settings" do
      assert FeedMonitor::ApplicationMailer < ActionMailer::Base

      defaults = FeedMonitor::ApplicationMailer.default
      assert_equal "from@example.com", defaults[:from]
      assert_equal "mailer", FeedMonitor::ApplicationMailer._layout
    end
  end
end
