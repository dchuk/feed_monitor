# frozen_string_literal: true

# Configure Mission Control for the dummy host app so the dashboard is usable in
# development and system tests without additional setup.
if defined?(MissionControl::Jobs)
  MissionControl::Jobs.tap do |config|
    config.http_basic_auth_user = ENV.fetch("MISSION_CONTROL_JOBS_USER", "feedmonitor")
    config.http_basic_auth_password = ENV.fetch("MISSION_CONTROL_JOBS_PASSWORD", "change-me")
  end
end
