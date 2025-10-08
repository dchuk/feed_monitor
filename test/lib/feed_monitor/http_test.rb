require "test_helper"
require "stringio"
require "zlib"

module FeedMonitor
  class HTTPTest < ActiveSupport::TestCase
    setup do
      @connection = FeedMonitor::HTTP.client
    end

    test "configures faraday connection with timeouts, redirects, and compression" do
      handlers = @connection.builder.handlers

      assert_equal FeedMonitor::HTTP::DEFAULT_TIMEOUT, @connection.options.timeout
      assert_equal FeedMonitor::HTTP::DEFAULT_OPEN_TIMEOUT, @connection.options.open_timeout

      follow_redirects = handlers.find { |handler| handler.klass == Faraday::FollowRedirects::Middleware }

      refute_nil follow_redirects
      assert_equal FeedMonitor::HTTP::DEFAULT_MAX_REDIRECTS,
                   follow_redirects.instance_variable_get(:@kwargs)[:limit]
      assert_includes handlers.map(&:klass), Faraday::FollowRedirects::Middleware
      assert_includes handlers.map(&:klass), Faraday::Gzip::Middleware
      assert_includes handlers.map(&:klass), Faraday::Response::RaiseError
    end

    test "adds retry middleware with exponential backoff" do
      retry_handler = @connection.builder.handlers.find { |handler| handler.klass == Faraday::Retry::Middleware }
      refute_nil retry_handler

      options = retry_handler.instance_variable_get(:@kwargs)

      assert_equal 4, options[:max]
      assert_equal 0.5, options[:interval]
      assert_equal 0.5, options[:interval_randomness]
      assert_equal 2, options[:backoff_factor]
      assert_equal FeedMonitor::HTTP::RETRY_STATUSES, options[:retry_statuses]
    end

    test "supports proxy arguments" do
      proxy_connection = FeedMonitor::HTTP.client(proxy: "http://proxy.test:8080")

      assert_equal "http://proxy.test:8080", proxy_connection.proxy.uri.to_s
    end

    test "allows overriding headers while preserving defaults" do
      custom = FeedMonitor::HTTP.client(headers: { "User-Agent" => "FeedMonitor/Test" })

      assert_equal "FeedMonitor/Test", custom.headers["User-Agent"]
      assert_equal "application/rss+xml, application/atom+xml, application/json;q=0.9, text/xml;q=0.8", custom.headers["Accept"]
      assert_equal "gzip,deflate", custom.headers["Accept-Encoding"]
    end

    test "fetches and parses gzipped feeds" do
      body = File.read(file_fixture("feeds/rss_sample.xml"))

      stub_request(:get, "https://example.com/feed.rss")
        .to_return(
          status: 200,
          body: gzip(body),
          headers: {
            "Content-Type" => "application/rss+xml",
            "Content-Encoding" => "gzip"
          }
        )

      connection = FeedMonitor::HTTP.client
      response = connection.get("https://example.com/feed.rss")

      assert_equal body, response.body

      feed = Feedjira.parse(response.body)
      assert_equal "Example RSS Feed", feed.title
    end

    private

    def gzip(str)
      buffer = StringIO.new
      Zlib::GzipWriter.wrap(buffer) { |gz| gz.write(str) }
      buffer.string
    end
  end
end
