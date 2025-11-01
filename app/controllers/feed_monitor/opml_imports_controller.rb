# frozen_string_literal: true

module FeedMonitor
  class OpmlImportsController < ApplicationController
    require "securerandom"

    SESSION_TOKEN_KEY = "feed_monitor_opml_import_token".freeze
    STATE_TTL = 30.minutes
    STATE_CACHE_PREFIX = "feed_monitor:opml_import:wizard".freeze
    STATE_STORE = ActiveSupport::Cache::MemoryStore.new(size: 32.megabytes)

    before_action :ensure_wizard_state!, only: %i[preview confirm start progress]

    def new
      reset_wizard_state
      @wizard = {}
    end

    def create
      uploaded_file = params.dig(:opml_import, :file)
      return respond_with_validation_error("Please choose an OPML file to upload") if uploaded_file.blank?

      reset_wizard_state

      parser_result = FeedMonitor::OPML::Parser.call(opml: uploaded_file.read)
      token = SecureRandom.uuid
      uploaded_at = Time.current
      initiated_by = current_actor_metadata
      file_size = safe_file_size(uploaded_file)
      outline_count = parser_result.outlines.size

      FeedMonitor::Importing::OpmlImportProgress.start_import(
        token: token,
        upload: {
          file_name: uploaded_file.original_filename,
          file_size: file_size,
          outline_count: outline_count,
          version: parser_result.version,
          started_at: uploaded_at
        },
        actor: initiated_by
      )

      state = build_wizard_state(
        file_name: uploaded_file.original_filename,
        file_size: file_size,
        parser_result:,
        initiated_by: initiated_by,
        uploaded_at: uploaded_at
      )

      store_wizard_state(state, token: token)
      session[SESSION_TOKEN_KEY] = token
      @wizard = state
      filter = state["filter"]

      respond_to do |format|
        format.html { redirect_to feed_monitor.opml_import_preview_path }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "opml-import-frame",
            view_context.render(
              template: "feed_monitor/opml_imports/preview",
              locals: { wizard: @wizard, filter: }
            )
          )
        end
      end
    rescue StandardError => error
      Rails.logger.error { "[OPML IMPORT] Failed to process upload: #{error.class}: #{error.message}" }
      respond_with_validation_error("The uploaded file could not be processed: #{error.message}")
    end

    def preview
      state = load_wizard_state
      selection = params.dig(:opml_import, :selection) || params[:selection]
      visible_urls = Array(params.dig(:opml_import, :visible)).map(&:to_s)

      if selection.present? || visible_urls.present?
        selected_urls = Array(selection).map(&:to_s)
        outlines = state.fetch("outlines", []).map do |outline|
          feed_url = outline["feed_url"]
          if visible_urls.include?(feed_url)
            outline.merge("selected" => selected_urls.include?(feed_url))
          else
            outline
          end
        end

        state = state.merge("outlines" => outlines)
      end

      requested_filter = params.dig(:opml_import, :filter) || params[:filter]
      filter = normalize_filter(requested_filter) || state["filter"] || DEFAULT_FILTER
      state = state.merge("filter" => filter)
      store_wizard_state(state)

      @wizard = state
      @filter = filter
    end

    def confirm
      state = load_wizard_state
      selected_urls = Array(params.dig(:opml_import, :selection)).map(&:to_s)

      updated_outlines = state["outlines"].map do |outline|
        outline.merge("selected" => selected_urls.include?(outline["feed_url"]))
      end

      if updated_outlines.none? { |outline| outline["selected"] }
        new_state = state.merge("outlines" => updated_outlines)
        store_wizard_state(new_state)
        @wizard = load_wizard_state
        filter = @wizard["filter"] || DEFAULT_FILTER

        respond_to do |format|
          format.html do
            flash.now[:alert] = "Select at least one source to import."
            render :preview, status: :unprocessable_entity
          end
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              "opml-import-frame",
              view_context.render(
                template: "feed_monitor/opml_imports/preview",
                locals: { wizard: @wizard, error_message: "Select at least one source to import.", filter: }
              )
            ), status: :unprocessable_entity
          end
        end
        return
      end

      state = state.merge("outlines" => updated_outlines, "errors" => [])
      store_wizard_state(state)

      @selected_outlines = selected_outlines(state).sort_by { |outline| outline["name"].to_s.downcase }
      @wizard = state
    end

    def start
      state = load_wizard_state
      selection = params.dig(:opml_import, :selection)

      if selection.present?
        selected_urls = Array(selection).map(&:to_s)
        state = state.merge(
          "outlines" => state.fetch("outlines", []).map do |outline|
            outline.merge("selected" => selected_urls.include?(outline["feed_url"]))
          end
        )
        store_wizard_state(state)
      end
      selected = selected_outlines(state)
      if selected.empty?
        redirect_to feed_monitor.opml_import_confirm_path, allow_other_host: false
        return
      end

      token = current_token
      entries = import_entries(selected)

      if token.present?
        FeedMonitor::Importing::OpmlImportProgress.reset!(token)
        FeedMonitor::Importing::OpmlImportProgress.merge_expected_entries(token:, entries:)

        entries.each do |entry|
          FeedMonitor::OpmlImportJob.perform_later(token, entry)
        end
      end

      store_wizard_state(state.merge("status" => "in_progress"))
      redirect_to feed_monitor.opml_import_progress_path
    end

    def progress
      @wizard = load_wizard_state
      @token = current_token

      progress_state = FeedMonitor::Importing::OpmlImportProgress.progress(@token)
      progress_state ||= default_progress_state

      @progress = progress_state
      @results = progress_state.fetch("ordered_results", [])
      @status = progress_state.fetch("status", "pending")
      @audit_entries = progress_state.fetch("audit_entries", [])
      @upload_metadata = progress_state["upload"] || {}
    end

    private

    def load_wizard_state
      token = current_token
      return unless token

      cached = state_store.read(cache_key(token))
      cached ? Marshal.load(Marshal.dump(cached)) : nil
    end

    def ensure_wizard_state!
      return if load_wizard_state.present?

      reset_wizard_state
      redirect_to feed_monitor.new_opml_import_path, allow_other_host: false
      throw :abort
    end

    def store_wizard_state(state, token: current_token)
      key = cache_key(token)
      return unless key

      state_store.write(key, Marshal.load(Marshal.dump(state)), expires_in: STATE_TTL)
    end

    def reset_wizard_state
      token = current_token
      state_store.delete(cache_key(token)) if token.present?
      session.delete(SESSION_TOKEN_KEY)
    end

    def build_wizard_state(file_name:, file_size:, parser_result:, initiated_by:, uploaded_at:)
      outlines = parser_result.outlines.map { |outline| outline_to_hash(outline).merge("selected" => true) }
      enriched_outlines = enrich_outlines(outlines)

      {
        "file_name" => file_name,
        "file_size" => file_size,
        "version" => parser_result.version,
        "uploaded_at" => uploaded_at,
        "initiated_by" => initiated_by,
        "outlines" => enriched_outlines,
        "errors" => parser_result.errors.map { |error| error_to_hash(error) },
        "filter" => DEFAULT_FILTER,
        "status" => "pending"
      }
    end

    def outline_to_hash(outline)
      {
        "name" => outline.name,
        "feed_url" => outline.feed_url,
        "raw_feed_url" => outline.raw_feed_url,
        "website_url" => outline.website_url,
        "feed_type" => outline.feed_type,
        "categories" => Array(outline.categories),
        "language" => outline.language
      }
    end

    def enrich_outlines(outlines)
      feed_urls = outlines.map { |outline| outline["feed_url"] }.compact
      existing_sources = FeedMonitor::Source.where(feed_url: feed_urls).index_by(&:feed_url)

      outlines.map do |outline|
        source = existing_sources[outline["feed_url"]]

        outline.merge(
          "duplicate" => source.present?,
          "existing_source" => source ? existing_source_snapshot(source) : nil,
          "decision" => default_decision_for(source.present?)
        )
      end
    end

    def existing_source_snapshot(source)
      {
        "id" => source.id,
        "name" => source.name,
        "fetch_status" => source.fetch_status,
        "last_fetched_at" => source.last_fetched_at,
        "items_count" => source.items_count
      }
    end

    def error_to_hash(error)
      {
        "code" => error.code,
        "message" => error.message,
        "outline" => error.outline_attributes
      }
    end

    def selected_outlines(state)
      state.fetch("outlines", []).select { |outline| outline["selected"] }
    end

    def import_entries(outlines)
      outlines.map { |outline| import_entry_for(outline) }
    end

    def import_entry_for(outline)
      entry = outline.slice("name", "feed_url", "website_url", "categories")
      decision = (outline["decision"].presence || default_decision_for(outline["duplicate"]))
      entry["decision"] = decision

      existing_id = outline.dig("existing_source", "id")
      entry["existing_source_id"] = existing_id if existing_id.present?
      entry
    end

    def default_decision_for(duplicate)
      duplicate ? "update" : "create"
    end

    def default_progress_state
      {
        "results" => {},
        "ordered_results" => [],
        "status" => "pending",
        "audit_entries" => [],
        "upload" => nil
      }
    end

    def filtered_outlines(outlines, filter)
      case filter
      when "new"
        outlines.reject { |outline| outline["duplicate"] }
      when "existing"
        outlines.select { |outline| outline["duplicate"] }
      else
        outlines
      end
    end

    def normalize_filter(raw_value)
      value = raw_value.to_s.downcase
      return value if %w[all new existing].include?(value)

      nil
    end

    DEFAULT_FILTER = "all"

    def current_token
      session[SESSION_TOKEN_KEY]
    end

    def cache_key(token = current_token)
      return unless token

      self.class.cache_key_for(token)
    end

    def respond_with_validation_error(message)
      @wizard = load_wizard_state || {}

      respond_to do |format|
        format.html do
          flash.now[:alert] = message
          render :new, status: :unprocessable_entity
        end
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "opml-import-messages",
            partial: "feed_monitor/opml_imports/messages",
            locals: { messages: [message], variant: :error }
          ), status: :unprocessable_entity
        end
      end
    end

    def current_actor_metadata
      user = feed_monitor_current_user
      return { "label" => "Unknown admin" } unless user

      name = safe_attribute(user, :name)
      email = safe_attribute(user, :email)
      identifier = safe_attribute(user, :id)

      label = [name, email, user].find do |value|
        next unless value

        value.respond_to?(:presence) ? value.presence : value.to_s.presence
      end || "Unknown admin"

      metadata = {}
      metadata["id"] = identifier if identifier.present?
      metadata["name"] = name.to_s if name.present?
      metadata["email"] = email.to_s if email.present?
      metadata["label"] = label.to_s
      metadata
    end

    def safe_attribute(object, attribute)
      return unless object

      if object.respond_to?(attribute)
        object.public_send(attribute)
      elsif object.respond_to?(:[])
        object[attribute] || object[attribute.to_s]
      end
    end

    def safe_file_size(uploaded_file)
      return unless uploaded_file

      if uploaded_file.respond_to?(:size)
        uploaded_file.size
      elsif uploaded_file.respond_to?(:tempfile) && uploaded_file.tempfile.respond_to?(:size)
        uploaded_file.tempfile.size
      end
    end

    class << self
      def cache_key_for(token)
        "#{STATE_CACHE_PREFIX}:#{token}"
      end

      def state_store
        STATE_STORE
      end
    end

    def state_store
      self.class.state_store
    end
  end
end
