# frozen_string_literal: true

# Example instrumentation wiring for host applications. This initializer
# subscribes to Feedmon notifications and logs structured payloads so you
# can forward them to your logging/metrics stack.
ActiveSupport::Notifications.subscribe(/feedmon\.(fetch|scheduler|dashboard)\./) do |name, started, finished, _id, payload|
  duration_ms = ((finished - started) * 1000.0).round(2)

  Rails.logger.info(
    "[Feedmon] #{name} duration=#{duration_ms}ms payload=#{payload.except(:item, :items).inspect}"
  )
end

# Expose metrics through the example controller copied by the template.
Rails.application.config.to_prepare do
  Feedmon::Metrics.increment(:advanced_template_loaded)
end
