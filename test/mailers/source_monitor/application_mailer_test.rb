# frozen_string_literal: true

require "test_helper"

module SourceMonitor
  class ApplicationMailerTest < ActiveSupport::TestCase
    test "inherits from ActionMailer::Base with default settings" do
      assert SourceMonitor::ApplicationMailer < ActionMailer::Base

      defaults = SourceMonitor::ApplicationMailer.default
      assert_equal "from@example.com", defaults[:from]
      assert_equal "mailer", SourceMonitor::ApplicationMailer._layout
    end
  end
end
