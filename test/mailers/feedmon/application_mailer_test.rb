# frozen_string_literal: true

require "test_helper"

module Feedmon
  class ApplicationMailerTest < ActiveSupport::TestCase
    test "inherits from ActionMailer::Base with default settings" do
      assert Feedmon::ApplicationMailer < ActionMailer::Base

      defaults = Feedmon::ApplicationMailer.default
      assert_equal "from@example.com", defaults[:from]
      assert_equal "mailer", Feedmon::ApplicationMailer._layout
    end
  end
end
