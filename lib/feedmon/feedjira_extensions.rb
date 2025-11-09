# frozen_string_literal: true

require "feedjira"
require "sax-machine"

module Feedmon
  module FeedjiraExtensions
    class MediaThumbnail
      include SAXMachine

      attribute :url
      attribute :width
      attribute :height
    end

    class MediaContent
      include SAXMachine

      attribute :url
      attribute :type
      attribute :medium
      attribute :height
      attribute :width
      attribute :"fileSize", as: :file_size
      attribute :duration
      attribute :expression
    end

    class Enclosure
      include SAXMachine

      attribute :url
      attribute :type
      attribute :length
    end

    class AtomAuthor
      include SAXMachine

      element :name
      element :email
      element :uri
    end

    class AtomLink
      include SAXMachine

      attribute :href
      attribute :rel
      attribute :type
      attribute :length
    end

    module_function

    def apply!
      return if @applied

      extend_rss_entry
      extend_atom_entry

      @applied = true
    end

    def extend_rss_entry
      Feedjira::Parser::RSSEntry.element :"media:keywords", as: :media_keywords_raw
      Feedjira::Parser::RSSEntry.element :"itunes:keywords", as: :itunes_keywords_raw
      Feedjira::Parser::RSSEntry.element :"slash:comments", as: :slash_comments_raw
      Feedjira::Parser::RSSEntry.elements :"media:thumbnail",
        as: :media_thumbnail_nodes,
        class: MediaThumbnail
      Feedjira::Parser::RSSEntry.elements :"media:content",
        as: :media_content_nodes,
        class: MediaContent
      Feedjira::Parser::RSSEntry.elements :enclosure,
        as: :enclosure_nodes,
        class: Enclosure

      Feedjira::Parser::RSSEntry.prepend(RSSAuthorCapture)
    end

    def extend_atom_entry
      Feedjira::Parser::AtomEntry.elements :author,
        as: :author_nodes,
        class: AtomAuthor
      Feedjira::Parser::AtomEntry.elements :link,
        as: :link_nodes,
        class: AtomLink
    end
    module RSSAuthorCapture
      def author=(value)
        (@feedmon_rss_authors ||= []) << value if value
        super
      end

      def rss_authors
        Array(@feedmon_rss_authors)
      end
    end
  end
end

Feedmon::FeedjiraExtensions.apply!
