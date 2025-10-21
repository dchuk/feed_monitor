# frozen_string_literal: true

module FeedMonitor
  if defined?(::ActionMailer::Base)
    class ApplicationMailer < ::ActionMailer::Base
      default from: "from@example.com"
      layout "mailer"
    end
  else
    # Define a no-op mailer so API-only host apps (which skip Action Mailer)
    # can autoload this constant without pulling in the framework.
    class ApplicationMailer
    end
  end
end
