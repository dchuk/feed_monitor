require_relative "lib/feed_monitor/version"

Gem::Specification.new do |spec|
  spec.name        = "feed_monitor"
  spec.version     = FeedMonitor::VERSION
  spec.authors     = [ "dchuk" ]
  spec.email       = [ "darrindemchuk@gmail.com" ]
  spec.homepage    = "https://github.com/darrindemchuk/feed_monitor"
  spec.summary     = "TODO: Summary of FeedMonitor."
  spec.description = "TODO: Description of FeedMonitor."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 8.0.2.1"
  spec.add_dependency "tailwindcss-rails"
  spec.add_dependency "turbo-rails"
  spec.add_dependency "feedjira", "~> 3.2"
  spec.add_dependency "faraday", "~> 2.9"
  spec.add_dependency "faraday-retry", "~> 2.2"
  spec.add_dependency "faraday-follow_redirects", "~> 0.4"
  spec.add_dependency "faraday-gzip", "~> 3.0"
  spec.add_dependency "nokolexbor", "~> 0.5"
  spec.add_dependency "ruby-readability", "~> 0.7"
  spec.add_dependency "solid_queue", ">= 0.3"
  spec.add_dependency "solid_cable", ">= 0.2"
  spec.add_dependency "ransack", "~> 4.2"
end
