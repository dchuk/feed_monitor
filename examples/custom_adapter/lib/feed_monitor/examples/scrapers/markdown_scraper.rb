# frozen_string_literal: true

require "action_view"

module FeedMonitor
  module Examples
    module Scrapers
      class MarkdownScraper < FeedMonitor::Scrapers::Base
        class << self
          def default_settings
            {
              "wrap_in_article" => true,
              "include_plain_text" => true
            }
          end
        end

        def call
          markdown = extract_markdown
          return Result.new(status: :failed, html: nil, content: nil, metadata: failure_metadata("blank markdown")) if markdown.blank?

          html = render_markdown(markdown)
          html = wrap_in_article(html) if settings["wrap_in_article"]

          Result.new(
            status: :success,
            html: html,
            content: settings["include_plain_text"] ? plain_text(html) : html,
            metadata: success_metadata(html)
          )
        rescue StandardError => error
          Result.new(status: :failed, html: nil, content: nil, metadata: failure_metadata(error.message))
        end

        private

        def extract_markdown
          return item.scraped_content if item.respond_to?(:scraped_content) && item.scraped_content.present?
          return item.content if item.respond_to?(:content) && item.content.present?
          return item.summary if item.respond_to?(:summary)

          ""
        end

        def render_markdown(markdown)
          text = markdown.to_s.dup

          text = text.split("\n").map do |line|
            case line
            when /\A### (.+)\z/ then "<h3>#{Regexp.last_match(1)}</h3>"
            when /\A## (.+)\z/ then "<h2>#{Regexp.last_match(1)}</h2>"
            when /\A# (.+)\z/ then "<h1>#{Regexp.last_match(1)}</h1>"
            else
              line
            end
          end.join("\n")

          text.gsub!(/\*\*(.+?)\*\*/, "<strong>\\1</strong>")
          text.gsub!(/__(.+?)__/, "<strong>\\1</strong>")
          text.gsub!(/_(.+?)_/, "<em>\\1</em>")
          text.gsub!(/\*(.+?)\*/, "<em>\\1</em>")
          text.gsub!(/\[(.+?)\]\((.+?)\)/, '<a href="\\2">\\1</a>')

          blocks = text.split(/\n{2,}/).map { |block| block.strip }.reject(&:blank?)

          blocks.map do |block|
            if block.match?(/\A<h[1-6]>.*<\/h[1-6]>\z/)
              block
            else
              "<p>#{block}</p>"
            end
          end.join
        end

        def wrap_in_article(html)
          %(<article data-scraper="markdown">#{html}</article>)
        end

        def plain_text(html)
          converted = html.gsub(/<\/?(p|h[1-6])>/, "\n")
          stripped = ActionView::Base.full_sanitizer.sanitize(converted)
          stripped.split("\n").map(&:strip).reject(&:blank?).join("\n")
        end

        def success_metadata(html)
          {
            adapter: self.class.adapter_name,
            settings: settings,
            characters: html.length,
            rendered_at: Time.current
          }
        end

        def failure_metadata(reason)
          {
            adapter: self.class.adapter_name,
            settings: settings,
            error: reason,
            failure_at: Time.current
          }
        end
      end
    end
  end
end
