# frozen_string_literal: true

require "test_helper"
require "yaml"

module FeedMonitor
  class DockerConfigTest < ActiveSupport::TestCase
    COMPOSE_PATH = FeedMonitor::Engine.root.join("examples/docker/docker-compose.yml")

    test "compose file defines core services" do
      config = YAML.safe_load(COMPOSE_PATH.read, aliases: true)
      services = config.fetch("services")

      %w[web worker scheduler postgres redis].each do |service|
        assert services.key?(service), "expected docker compose to include #{service} service"
      end
    end
  end
end
