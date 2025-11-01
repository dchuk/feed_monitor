# frozen_string_literal: true

require "active_support/cache"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/time"
require "active_support/core_ext/object/blank"
require "digest/sha1"

module FeedMonitor
  module Importing
    module OpmlImportProgress
      STATE_TTL = 30.minutes
      CACHE_PREFIX = "feed_monitor:opml_import:progress".freeze
      STREAM_PREFIX = "feed_monitor_opml_import_progress".freeze
      STATE_STORE = ActiveSupport::Cache::MemoryStore.new(size: 32.megabytes)
      AUDIT_ENTRY_LIMIT = 100

      module_function

      def start_import(token:, upload:, actor: {})
        reset!(token)

        normalized_upload = normalize_upload_metadata(upload, actor)

        mutate_state(token) do |state|
          state.replace(default_state)
          state["upload"] = normalized_upload
          state["audit_entries"] = [upload_audit_entry(normalized_upload)]
          state
        end
      end

      def already_processed?(token:, entry:)
        state = fetch_state(token)
        return false unless state

        key = entry_key(entry)
        processed_keys = state.fetch("processed_keys", [])
        processed_keys.include?(key)
      end

      def record_result(token:, entry:, result:)
        mutate_state(token) do |state|
          state["audit_entries"] ||= []
          key = entry_key(entry)
          processed_keys = state.fetch("processed_keys")
          if completed_result?(result) && !processed_keys.include?(key)
            processed_keys << key
          end

          entry_summary = summarized_result(entry:, result:)
          state["results"][key] = entry_summary

          existing_index = state["ordered_results"].index do |existing|
            existing["feed_url"] == entry_summary["feed_url"] && existing["decision"] == entry_summary["decision"]
          end

          if existing_index
            state["ordered_results"][existing_index] = entry_summary
          else
            state["ordered_results"] << entry_summary
          end

          state["last_result_at"] = Time.current
          state["status"] = determine_status(state)
          append_health_check_audit_entry(state:, entry_summary:, result:)
          state
        end
      end

      def broadcast_update(token:, entry:, result:)
        state = progress(token)
        return unless state

        Turbo::StreamsChannel.broadcast_replace_to(
          stream_name(token),
          target: "opml-import-progress-results",
          partial: "feed_monitor/opml_imports/progress_results",
          locals: {
            progress: state,
            results: state.fetch("ordered_results", []),
            status: state.fetch("status", "in_progress"),
            audit_entries: state.fetch("audit_entries", [])
          }
        )
      rescue StandardError => error
        log_broadcast_failure(error)
      end

      def merge_expected_entries(token:, entries:)
        mutate_state(token) do |state|
          entries.each do |entry|
            key = entry_key(entry)
            summary = state["results"][key] ||= summarized_result(entry:, result: nil)

            unless state["ordered_results"].any? { |existing| existing["feed_url"] == summary["feed_url"] && existing["decision"] == summary["decision"] }
              state["ordered_results"] << summary.dup
            end
          end

          state["status"] = determine_status(state)
          state
        end
      end

      def progress(token)
        fetch_state(token)
      end

      def reset!(token)
        STATE_STORE.delete(cache_key(token))
      end

      def cache_key(token)
        "#{CACHE_PREFIX}:#{token}"
      end

      def stream_name(token)
        return unless token

        "#{STREAM_PREFIX}_#{token}"
      end

      def mutate_state(token)
        state = fetch_state(token) || default_state
        updated = yield(state)
        STATE_STORE.write(cache_key(token), serialize_state(updated), expires_in: STATE_TTL)
      end

      def fetch_state(token)
        raw = STATE_STORE.read(cache_key(token))
        deserialize_state(raw)
      end

      def determine_status(state)
        results = state.fetch("results")
        return "pending" if results.empty?

        completed = results.values.count { |entry| completed_status?(entry["status"]) }
        total = results.size

        completed >= total ? "completed" : "in_progress"
      end

      def summarized_result(entry:, result:)
        hash = {
          "feed_url" => entry.to_h.with_indifferent_access[:feed_url],
          "name" => entry.to_h.with_indifferent_access[:name],
          "decision" => entry.to_h.with_indifferent_access[:decision],
          "status" => result ? result.status.to_s : "pending",
          "message" => result&.message,
          "source_id" => result&.source&.id,
          "health_check" => serialize_health_check(result&.health_check)
        }

        hash["status"] = "skipped" if result&.skipped?
        hash
      end

      def completed_status?(status)
        %w[created updated skipped completed].include?(status.to_s)
      end

      def completed_result?(result)
        result&.success? || result&.skipped?
      end

      def serialize_health_check(health_check)
        normalized_health_check(health_check)&.transform_keys(&:to_sym)
      end

      def log_broadcast_failure(error)
        return unless defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger

        Rails.logger.debug do
          "[FeedMonitor::Importing::OpmlImportProgress] Broadcast failed: #{error.class}: #{error.message}"
        end
      end

      def default_state
        {
          "results" => {},
          "ordered_results" => [],
          "processed_keys" => [],
          "status" => "pending",
          "last_result_at" => nil,
          "audit_entries" => [],
          "upload" => nil
        }
      end

      def entry_key(entry)
        attributes = entry.to_h.to_a.sort_by { |(key, _value)| key.to_s }
        Digest::SHA1.hexdigest(attributes.to_s)
      end

      def serialize_state(state)
        Marshal.dump(state)
      end

      def deserialize_state(raw)
        return unless raw

        Marshal.load(raw)
      end

      def normalize_upload_metadata(upload, actor)
        upload ||= {}
        actor ||= {}

        started_at = upload[:started_at] || upload["started_at"] || Time.current
        file_name = (upload[:file_name] || upload["file_name"]).to_s.presence
        file_size = upload[:file_size] || upload["file_size"]
        outline_count = upload[:outline_count] || upload["outline_count"]
        version = upload[:version] || upload["version"]

        normalized_actor = normalize_actor(actor)

        {
          "file_name" => file_name,
          "file_size" => file_size,
          "outline_count" => outline_count,
          "version" => version,
          "started_at" => started_at,
          "actor" => normalized_actor
        }.compact
      end

      def normalize_actor(actor)
        return { "label" => "Unknown admin" } if actor.blank?

        name = safe_value(actor, :name)
        email = safe_value(actor, :email)
        identifier = safe_value(actor, :id)

        label = if name.respond_to?(:presence) && name.presence
          name.to_s
        elsif email.respond_to?(:presence) && email.presence
          email.to_s
        elsif actor.respond_to?(:to_s)
          actor.to_s
        else
          "Unknown admin"
        end

        {
          "id" => identifier,
          "name" => name&.to_s,
          "email" => email&.to_s,
          "label" => label
        }.compact
      end

      def safe_value(object, method_name)
        if object.respond_to?(method_name)
          object.public_send(method_name)
        elsif object.respond_to?(:[]) && object.key?(method_name)
          object[method_name]
        elsif object.respond_to?(:[]) && object.key?(method_name.to_s)
          object[method_name.to_s]
        end
      end

      def upload_audit_entry(upload)
        return nil unless upload

        {
          "kind" => "upload",
          "recorded_at" => upload["started_at"] || Time.current,
          "file_name" => upload["file_name"],
          "file_size" => upload["file_size"],
          "outline_count" => upload["outline_count"],
          "version" => upload["version"],
          "actor" => upload["actor"]
        }.compact
      end

      def append_health_check_audit_entry(state:, entry_summary:, result:)
        normalized = normalized_health_check(result&.health_check)
        return unless normalized&.any?

        state["audit_entries"] << {
          "kind" => "health_check",
          "recorded_at" => Time.current,
          "feed_name" => entry_summary["name"],
          "feed_url" => entry_summary["feed_url"],
          "success" => normalized[:success],
          "message" => normalized[:message],
          "log_id" => normalized[:log_id],
          "result_status" => entry_summary["status"],
          "decision" => entry_summary["decision"],
          "source_id" => entry_summary["source_id"]
        }.compact

        trim_audit_entries!(state)
      end

      def normalized_health_check(health_check)
        return unless health_check

        hash = if health_check.respond_to?(:to_h)
          health_check.to_h
        else
          {}
        end

        hash = hash.transform_keys { |key| key.to_s.delete_suffix("?").to_sym }

        hash[:success] = health_check.success? if hash[:success].nil? && health_check.respond_to?(:success?)
        hash[:message] = health_check.message if hash[:message].nil? && health_check.respond_to?(:message)
        hash[:log_id] = health_check.log_id if hash[:log_id].nil? && health_check.respond_to?(:log_id)

        hash.compact
      end

      def trim_audit_entries!(state)
        entries = state["audit_entries"]
        return unless entries.is_a?(Array)

        state["audit_entries"] = entries.last(AUDIT_ENTRY_LIMIT)
      end
    end
  end
end
