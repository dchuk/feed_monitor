# frozen_string_literal: true

require "time"
require "digest"
require "feed_monitor/http"
require "feed_monitor/fetching/fetch_error"
require "feed_monitor/fetching/retry_policy"
require "feed_monitor/items/item_creator"

module FeedMonitor
  module Fetching
    class FeedFetcher
      Result = Struct.new(:status, :feed, :response, :body, :error, :item_processing, :retry_decision, keyword_init: true)
      EntryProcessingResult = Struct.new(
        :created,
        :updated,
        :failed,
        :items,
        :errors,
        :created_items,
        :updated_items,
        keyword_init: true
      )
      ResponseWrapper = Struct.new(:status, :headers, :body, keyword_init: true)

      MIN_FETCH_INTERVAL = 5.minutes.to_f
      MAX_FETCH_INTERVAL = 24.hours.to_f
      INCREASE_FACTOR = 1.25
      DECREASE_FACTOR = 0.75
      FAILURE_INCREASE_FACTOR = 1.5
      JITTER_PERCENT = 0.1

      attr_reader :source, :client, :jitter_proc

      def initialize(source:, client: nil, jitter: nil)
        @source = source
        @client = client
        @jitter_proc = jitter
      end

      def call
        attempt_started_at = Time.current
        instrumentation_payload = base_instrumentation_payload
        started_monotonic = FeedMonitor::Instrumentation.monotonic_time
        result = nil

        FeedMonitor::Instrumentation.fetch_start(instrumentation_payload)

        result = perform_fetch(attempt_started_at, instrumentation_payload)
      rescue FetchError => error
        result = handle_failure(error, started_at: attempt_started_at, instrumentation_payload:)
      rescue StandardError => error
        fetch_error = UnexpectedResponseError.new(error.message, original_error: error)
        result = handle_failure(fetch_error, started_at: attempt_started_at, instrumentation_payload:)
      ensure
        instrumentation_payload[:duration_ms] ||= duration_since(started_monotonic)
        FeedMonitor::Instrumentation.fetch_finish(instrumentation_payload)
        return result
      end

      private

      def base_instrumentation_payload
        {
          source_id: source.id,
          feed_url: source.feed_url
        }
      end

      def duration_since(started_monotonic)
        ((FeedMonitor::Instrumentation.monotonic_time - started_monotonic) * 1000.0).round(2)
      end

      def perform_fetch(started_at, instrumentation_payload)
        response = perform_request
        handle_response(response, started_at, instrumentation_payload)
      rescue TimeoutError, ConnectionError, HTTPError, ParsingError => error
        raise error
      rescue Faraday::TimeoutError => error
        raise TimeoutError.new(error.message, original_error: error)
      rescue Faraday::ConnectionFailed, Faraday::SSLError => error
        raise ConnectionError.new(error.message, original_error: error)
      rescue Faraday::ClientError => error
        raise build_http_error_from_faraday(error)
      rescue Faraday::Error => error
        raise FetchError.new(error.message, original_error: error)
      end

      def perform_request
        connection.get(source.feed_url)
      end

      def connection
        @connection ||= (client || FeedMonitor::HTTP.client(headers: request_headers))
      end

      def request_headers
        headers = (source.custom_headers || {}).transform_keys { |key| key.to_s }
        headers["If-None-Match"] = source.etag if source.etag.present?
        if source.last_modified.present?
          headers["If-Modified-Since"] = source.last_modified.httpdate
        end
        headers
      end

      def handle_response(response, started_at, instrumentation_payload)
        case response.status
        when 200
          handle_success(response, started_at, instrumentation_payload)
        when 304
          handle_not_modified(response, started_at, instrumentation_payload)
        else
          raise HTTPError.new(status: response.status, response: response)
        end
      end

      def handle_success(response, started_at, instrumentation_payload)
        duration_ms = elapsed_ms(started_at)
        body = response.body
        feed = parse_feed(body, response)
        processing = process_feed_entries(feed)

        feed_body_signature = body_digest(body)
        update_source_for_success(response, duration_ms, feed, feed_body_signature)
        create_fetch_log(
          response: response,
          duration_ms: duration_ms,
          started_at: started_at,
          feed: feed,
          success: true,
          body: body,
          feed_signature: feed_body_signature,
          items_created: processing.created,
          items_updated: processing.updated,
          items_failed: processing.failed,
          item_errors: processing.errors
        )

        instrumentation_payload[:success] = true
        instrumentation_payload[:status] = :fetched
        instrumentation_payload[:http_status] = response.status
        instrumentation_payload[:parser] = feed.class.name if feed
        instrumentation_payload[:items_created] = processing.created
        instrumentation_payload[:items_updated] = processing.updated
        instrumentation_payload[:items_failed] = processing.failed
        instrumentation_payload[:retry_attempt] = 0

        Result.new(status: :fetched, feed:, response:, body:, item_processing: processing)
      end

      def handle_not_modified(response, started_at, instrumentation_payload)
        duration_ms = elapsed_ms(started_at)

        update_source_for_not_modified(response, duration_ms)
        create_fetch_log(
          response: response,
          duration_ms: duration_ms,
          started_at: started_at,
          success: true
        )

        instrumentation_payload[:success] = true
        instrumentation_payload[:status] = :not_modified
        instrumentation_payload[:http_status] = response.status
        instrumentation_payload[:items_created] = 0
        instrumentation_payload[:items_updated] = 0
        instrumentation_payload[:items_failed] = 0
        instrumentation_payload[:retry_attempt] = 0

        Result.new(
          status: :not_modified,
          response: response,
          body: nil,
          item_processing: EntryProcessingResult.new(
            created: 0,
            updated: 0,
            failed: 0,
            items: [],
            errors: [],
            created_items: [],
            updated_items: []
          )
        )
      end

      def parse_feed(body, response)
        Feedjira.parse(body)
      rescue StandardError => error
        raise ParsingError.new(error.message, response: response, original_error: error)
      end

      def update_source_for_success(response, duration_ms, feed, feed_signature)
        attributes = {
          last_fetched_at: Time.current,
          last_fetch_duration_ms: duration_ms,
          last_http_status: response.status,
          last_error: nil,
          last_error_at: nil,
          failure_count: 0,
          feed_format: derive_feed_format(feed)
        }

        if (etag = response.headers["etag"] || response.headers["ETag"])
          attributes[:etag] = etag
        end

        if (last_modified_header = response.headers["last-modified"] || response.headers["Last-Modified"])
          parsed_time = parse_http_time(last_modified_header)
          attributes[:last_modified] = parsed_time if parsed_time
        end

        apply_adaptive_interval!(attributes, content_changed: feed_signature_changed?(feed_signature))
        attributes[:metadata] = updated_metadata(feed_signature: feed_signature)
        reset_retry_state!(attributes)
        source.update!(attributes)
      end

      def update_source_for_not_modified(response, duration_ms)
        attributes = {
          last_fetched_at: Time.current,
          last_fetch_duration_ms: duration_ms,
          last_http_status: response.status,
          last_error: nil,
          last_error_at: nil,
          failure_count: 0
        }

        if (etag = response.headers["etag"] || response.headers["ETag"])
          attributes[:etag] = etag
        end

        if (last_modified_header = response.headers["last-modified"] || response.headers["Last-Modified"])
          parsed_time = parse_http_time(last_modified_header)
          attributes[:last_modified] = parsed_time if parsed_time
        end

        apply_adaptive_interval!(attributes, content_changed: false)
        attributes[:metadata] = updated_metadata
        reset_retry_state!(attributes)
        source.update!(attributes)
      end

      def update_source_for_failure(error, duration_ms)
        now = Time.current
        attrs = {
          last_fetched_at: now,
          last_fetch_duration_ms: duration_ms,
          last_http_status: error.http_status,
          last_error: error.message,
          last_error_at: now,
          failure_count: source.failure_count.to_i + 1
        }

        apply_adaptive_interval!(attrs, content_changed: false, failure: true)
        attrs[:metadata] = updated_metadata
        decision = apply_retry_strategy!(attrs, error, now)
        source.update!(attrs)
        decision
      end

      def reset_retry_state!(attributes)
        attributes[:fetch_retry_attempt] = 0
        attributes[:fetch_circuit_opened_at] = nil
        attributes[:fetch_circuit_until] = nil
      end

      def apply_retry_strategy!(attributes, error, now)
        decision = FeedMonitor::Fetching::RetryPolicy.new(source:, error:, now:).decision

        if decision.open_circuit?
          attributes[:fetch_retry_attempt] = 0
          attributes[:fetch_circuit_opened_at] = now
          attributes[:fetch_circuit_until] = decision.circuit_until
          attributes[:next_fetch_at] = decision.circuit_until
          attributes[:backoff_until] = decision.circuit_until
        elsif decision.retry?
          attributes[:fetch_retry_attempt] = decision.next_attempt
          attributes[:fetch_circuit_opened_at] = nil
          attributes[:fetch_circuit_until] = nil
          unless source.adaptive_fetching_enabled? == false
            retry_at = now + decision.wait
            current_next = attributes[:next_fetch_at]
            attributes[:next_fetch_at] = [ current_next, retry_at ].compact.min
            attributes[:backoff_until] = retry_at
          end
        else
          attributes[:fetch_retry_attempt] = 0
        end

        decision
      rescue StandardError => policy_error
        Rails.logger.error(
          "[FeedMonitor] Failed to apply retry strategy for source #{source.id}: #{policy_error.class} - #{policy_error.message}"
        ) if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
        attributes[:fetch_retry_attempt] ||= 0
        attributes[:fetch_circuit_opened_at] ||= nil
        attributes[:fetch_circuit_until] ||= nil
        nil
      end

      def create_fetch_log(response:, duration_ms:, started_at:, success:, feed: nil, error: nil, body: nil, feed_signature: nil,
                           items_created: 0, items_updated: 0, items_failed: 0, item_errors: [])
        source.fetch_logs.create!(
          success:,
          started_at: started_at,
          completed_at: started_at + (duration_ms / 1000.0),
          duration_ms: duration_ms,
          http_status: response&.status,
          http_response_headers: normalized_headers(response&.headers),
          feed_size_bytes: body&.bytesize,
          items_in_feed: feed&.respond_to?(:entries) ? feed.entries.size : nil,
          items_created: items_created,
          items_updated: items_updated,
          items_failed: items_failed,
          error_class: error&.class&.name,
          error_message: error&.message,
          error_backtrace: error_backtrace(error),
          metadata: feed_metadata(feed, error: error, feed_signature: feed_signature, item_errors: item_errors)
        )
      end

      def derive_feed_format(feed)
        return unless feed

        feed.class.name.split("::").last.underscore
      end

      def feed_metadata(feed, error: nil, feed_signature: nil, item_errors: [])
        metadata = {}
        metadata[:parser] = feed.class.name if feed
        metadata[:error_code] = error.code if error&.respond_to?(:code)
        metadata[:feed_signature] = feed_signature if feed_signature
        metadata[:item_errors] = item_errors if item_errors.present?
        metadata
      end

      def normalized_headers(headers)
        return {} unless headers

        headers.to_h.transform_keys { |key| key.to_s.downcase }
      end

      def error_backtrace(error)
        return if error.nil? || error.original_error.nil?

        Array(error.original_error.backtrace).first(20).join("\n")
      end

      def parse_http_time(value)
        return if value.blank?

        Time.httpdate(value)
      rescue ArgumentError
        nil
      end

      def elapsed_ms(started_at)
        ((Time.current - started_at) * 1000.0).round
      end

      def handle_failure(error, started_at:, instrumentation_payload:)
        response = error.response
        body = response&.body
        duration_ms = elapsed_ms(started_at)

        retry_decision = update_source_for_failure(error, duration_ms)
        create_fetch_log(
          response: response,
          duration_ms: duration_ms,
          started_at: started_at,
          success: false,
          error: error,
          body: body
        )

        instrumentation_payload[:success] = false
        instrumentation_payload[:status] = :failed
        instrumentation_payload[:error_class] = error.class.name
        instrumentation_payload[:error_message] = error.message
        instrumentation_payload[:http_status] = error.http_status if error.http_status
        instrumentation_payload[:error_code] = error.code if error.respond_to?(:code)
        instrumentation_payload[:items_created] = 0
        instrumentation_payload[:items_updated] = 0
        instrumentation_payload[:items_failed] = 0
        instrumentation_payload[:retry_attempt] = retry_decision&.next_attempt ? retry_decision.next_attempt : 0

        Result.new(
          status: :failed,
          response: response,
          body: body,
          error: error,
          retry_decision: retry_decision,
          item_processing: EntryProcessingResult.new(
            created: 0,
            updated: 0,
            failed: 0,
            items: [],
            errors: [],
            created_items: [],
            updated_items: []
          )
        )
      end

      def build_http_error_from_faraday(error)
        response_hash = error.response || {}
        headers = response_hash[:headers] || response_hash[:response_headers] || {}
        ResponseWrapper.new(
          status: response_hash[:status],
          headers: headers,
          body: response_hash[:body]
        ).then do |response|
          status = response.status || 0
          message = error.message
          HTTPError.new(status: status, message: message, response: response, original_error: error)
        end
      end

      def feed_signature_changed?(feed_signature)
        return false if feed_signature.blank?

        (source.metadata || {}).fetch("last_feed_signature", nil) != feed_signature
      end

      def apply_adaptive_interval!(attributes, content_changed:, failure: false)
        if source.adaptive_fetching_enabled?
          interval_seconds = compute_next_interval_seconds(content_changed:, failure:)
          scheduled_time = Time.current + adjusted_interval_with_jitter(interval_seconds)
          scheduled_time = [ scheduled_time, source.backoff_until ].compact.max if source.backoff_until.present?

          attributes[:fetch_interval_minutes] = interval_minutes_for(interval_seconds)
          attributes[:next_fetch_at] = scheduled_time
          attributes[:backoff_until] = failure ? scheduled_time : nil
        else
          fixed_minutes = [ source.fetch_interval_minutes.to_i, 1 ].max
          attributes[:next_fetch_at] = Time.current + fixed_minutes.minutes
          attributes[:backoff_until] = nil
        end
      end

      def compute_next_interval_seconds(content_changed:, failure:)
        current = [ current_interval_seconds, min_fetch_interval_seconds ].max

        next_interval = if failure
                          current * failure_increase_factor_value
        elsif content_changed
                          current * decrease_factor_value
        else
                          current * increase_factor_value
        end

        next_interval = min_fetch_interval_seconds if next_interval < min_fetch_interval_seconds
        next_interval = max_fetch_interval_seconds if next_interval > max_fetch_interval_seconds
        next_interval.to_f
      end

      def current_interval_seconds
        source.fetch_interval_minutes.to_f * 60.0
      end

      def interval_minutes_for(interval_seconds)
        minutes = (interval_seconds / 60.0).round
        [ minutes, 1 ].max
      end

      def min_fetch_interval_seconds
        configured_seconds(fetching_config&.min_interval_minutes, MIN_FETCH_INTERVAL)
      end

      def max_fetch_interval_seconds
        configured_seconds(fetching_config&.max_interval_minutes, MAX_FETCH_INTERVAL)
      end

      def increase_factor_value
        configured_positive(fetching_config&.increase_factor, INCREASE_FACTOR)
      end

      def decrease_factor_value
        configured_positive(fetching_config&.decrease_factor, DECREASE_FACTOR)
      end

      def failure_increase_factor_value
        configured_positive(fetching_config&.failure_increase_factor, FAILURE_INCREASE_FACTOR)
      end

      def jitter_percent_value
        configured_non_negative(fetching_config&.jitter_percent, JITTER_PERCENT)
      end

      def updated_metadata(feed_signature: nil)
        metadata = (source.metadata || {}).dup
        metadata.delete("dynamic_fetch_interval_seconds")
        metadata["last_feed_signature"] = feed_signature if feed_signature.present?
        metadata
      end

      def adjusted_interval_with_jitter(interval_seconds)
        jitter = jitter_offset(interval_seconds)
        adjusted = interval_seconds + jitter
        adjusted = min_fetch_interval_seconds if adjusted < min_fetch_interval_seconds
        adjusted
      end

      def jitter_offset(interval_seconds)
        return 0 if interval_seconds <= 0
        return jitter_proc.call(interval_seconds) if jitter_proc.respond_to?(:call)

        jitter_range = interval_seconds * jitter_percent_value
        return 0 if jitter_range <= 0

        ((rand * 2) - 1) * jitter_range
      end

      def body_digest(body)
        return if body.blank?

        Digest::SHA256.hexdigest(body)
      end

      def process_feed_entries(feed)
        return EntryProcessingResult.new(
          created: 0,
          updated: 0,
          failed: 0,
          items: [],
          errors: [],
          created_items: [],
          updated_items: []
        ) unless feed.respond_to?(:entries)

        created = 0
        updated = 0
        failed = 0
        items = []
        created_items = []
        updated_items = []
        errors = []

        Array(feed.entries).each do |entry|
          begin
            result = FeedMonitor::Items::ItemCreator.call(source:, entry:)
            FeedMonitor::Events.run_item_processors(source:, entry:, result: result)
            items << result.item
            if result.created?
              created += 1
              created_items << result.item
              FeedMonitor::Events.after_item_created(item: result.item, source:, entry:, result: result)
            else
              updated += 1
              updated_items << result.item
            end
          rescue StandardError => error
            failed += 1
            errors << normalize_item_error(entry, error)
          end
        end

        EntryProcessingResult.new(
          created:,
          updated:,
          failed:,
          items:,
          errors: errors.compact,
          created_items:,
          updated_items:
        )
      end

      def configured_seconds(minutes_value, default)
        minutes = extract_numeric(minutes_value)
        return default unless minutes && minutes.positive?

        minutes * 60.0
      end

      def configured_positive(value, default)
        number = extract_numeric(value)
        return default unless number && number.positive?

        number
      end

      def configured_non_negative(value, default)
        number = extract_numeric(value)
        return default if number.nil?

        number.negative? ? 0.0 : number
      end

      def extract_numeric(value)
        return value if value.is_a?(Numeric)
        return value.to_f if value.respond_to?(:to_f)

        nil
      rescue StandardError
        nil
      end

      def fetching_config
        FeedMonitor.config.fetching
      end

      def normalize_item_error(entry, error)
        {
          guid: safe_entry_guid(entry),
          title: safe_entry_title(entry),
          error_class: error.class.name,
          error_message: error.message
        }
      rescue StandardError
        { error_class: error.class.name, error_message: error.message }
      end

      def safe_entry_guid(entry)
        if entry.respond_to?(:entry_id)
          entry.entry_id
        elsif entry.respond_to?(:id)
          entry.id
        end
      end

      def safe_entry_title(entry)
        entry.title if entry.respond_to?(:title)
      end
    end
  end
end
