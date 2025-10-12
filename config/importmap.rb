pin "@hotwired/stimulus", to: "feed_monitor/stimulus.js", preload: true
pin "feed_monitor/application", to: "feed_monitor/application.js", preload: true
pin_all_from FeedMonitor::Engine.root.join("app/assets/javascripts/feed_monitor/controllers"), under: "feed_monitor/controllers"
pin "stimulus-use", to: "feed_monitor/stimulus-use.js"
