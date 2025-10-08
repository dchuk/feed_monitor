# frozen_string_literal: true

require "feedjira"

Feedjira.configure do |config|
  config.parsers = [
    Feedjira::Parser::JSONFeed,
    Feedjira::Parser::Atom,
    Feedjira::Parser::AtomFeedBurner,
    Feedjira::Parser::AtomYoutube,
    Feedjira::Parser::AtomGoogleAlerts,
    Feedjira::Parser::GoogleDocsAtom,
    Feedjira::Parser::ITunesRSS,
    Feedjira::Parser::RSSFeedBurner,
    Feedjira::Parser::RSS
  ]

  config.strip_whitespace = true
end
