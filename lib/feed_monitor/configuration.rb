# frozen_string_literal: true

require "active_support/core_ext/string/inflections"

module FeedMonitor
  class Configuration
    attr_accessor :queue_namespace,
      :fetch_queue_name,
      :scrape_queue_name,
      :fetch_queue_concurrency,
      :scrape_queue_concurrency,
      :recurring_command_job_class,
      :job_metrics_enabled,
      :mission_control_enabled,
      :mission_control_dashboard_path

    attr_reader :http, :scrapers, :retention, :events

    DEFAULT_QUEUE_NAMESPACE = "feed_monitor"

    def initialize
      @queue_namespace = DEFAULT_QUEUE_NAMESPACE
      @fetch_queue_name = "#{DEFAULT_QUEUE_NAMESPACE}_fetch"
      @scrape_queue_name = "#{DEFAULT_QUEUE_NAMESPACE}_scrape"
      @fetch_queue_concurrency = 2
      @scrape_queue_concurrency = 2
      @recurring_command_job_class = nil
      @job_metrics_enabled = true
      @mission_control_enabled = false
      @mission_control_dashboard_path = nil
      @http = HTTPSettings.new
      @scrapers = ScraperRegistry.new
      @retention = RetentionSettings.new
      @events = Events.new
    end

    def queue_name_for(role)
      explicit_name =
        case role.to_sym
        when :fetch
          fetch_queue_name
        when :scrape
          scrape_queue_name
        else
          raise ArgumentError, "unknown queue role #{role.inspect}"
        end

      prefix = ActiveJob::Base.queue_name_prefix
      delimiter = ActiveJob::Base.queue_name_delimiter

      if prefix && !prefix.empty?
        [prefix, explicit_name].join(delimiter)
      else
        explicit_name
      end
    end

    def concurrency_for(role)
      case role.to_sym
      when :fetch
        fetch_queue_concurrency
      when :scrape
        scrape_queue_concurrency
      else
        raise ArgumentError, "unknown queue role #{role.inspect}"
      end
    end

    class HTTPSettings
      attr_accessor :timeout,
        :open_timeout,
        :max_redirects,
        :user_agent,
        :proxy,
        :headers,
        :retry_max,
        :retry_interval,
        :retry_interval_randomness,
        :retry_backoff_factor,
        :retry_statuses

      def initialize
        reset!
      end

      def reset!
        @timeout = 15
        @open_timeout = 5
        @max_redirects = 5
        @user_agent = default_user_agent
        @proxy = nil
        @headers = {}
        @retry_max = 4
        @retry_interval = 0.5
        @retry_interval_randomness = 0.5
        @retry_backoff_factor = 2
        @retry_statuses = nil
      end

      private

      def default_user_agent
        "FeedMonitor/#{FeedMonitor::VERSION}"
      end
    end

    class ScraperRegistry
      include Enumerable

      def initialize
        @adapters = {}
      end

      def register(name, adapter)
        key = normalize_name(name)
        @adapters[key] = normalize_adapter(adapter)
      end

      def unregister(name)
        @adapters.delete(normalize_name(name))
      end

      def adapter_for(name)
        adapter = @adapters[normalize_name(name)]
        adapter if adapter
      end

      def each(&block)
        @adapters.each(&block)
      end

      private

      def normalize_name(name)
        value = name.to_s
        raise ArgumentError, "Invalid scraper adapter name #{name.inspect}" unless value.match?(/\A[a-z0-9_]+\z/i)

        value.downcase
      end

      def normalize_adapter(adapter)
        constant = resolve_adapter(adapter)

        if defined?(FeedMonitor::Scrapers::Base) && !(constant <= FeedMonitor::Scrapers::Base)
          raise ArgumentError, "Scraper adapters must inherit from FeedMonitor::Scrapers::Base"
        end

        constant
      end

      def resolve_adapter(adapter)
        return adapter if adapter.is_a?(Class)

        if adapter.respond_to?(:to_s)
          constant_name = adapter.to_s
          begin
            return constant_name.constantize
          rescue NameError
            raise ArgumentError, "Unknown scraper adapter constant #{constant_name.inspect}"
          end
        end

        raise ArgumentError, "Invalid scraper adapter #{adapter.inspect}"
      end
    end

    class RetentionSettings
      attr_accessor :items_retention_days, :max_items

      def initialize
        @items_retention_days = nil
        @max_items = nil
        @strategy = :destroy
      end

      def strategy
        @strategy
      end

      def strategy=(value)
        normalized = normalize_strategy(value)
        @strategy = normalized unless normalized.nil?
      end

      private

      def normalize_strategy(value)
        return :destroy if value.nil?

        if value.respond_to?(:to_sym)
          candidate = value.to_sym
          valid =
            if defined?(FeedMonitor::Items::RetentionPruner::VALID_STRATEGIES)
              FeedMonitor::Items::RetentionPruner::VALID_STRATEGIES
            else
              %i[destroy soft_delete]
            end

          raise ArgumentError, "Invalid retention strategy #{value.inspect}" unless valid.include?(candidate)
          candidate
        else
          raise ArgumentError, "Invalid retention strategy #{value.inspect}"
        end
      end
    end

    class Events
      CALLBACK_KEYS = %i[after_item_created after_item_scraped after_fetch_completed].freeze

      def initialize
        @callbacks = Hash.new { |hash, key| hash[key] = [] }
        @item_processors = []
      end

      CALLBACK_KEYS.each do |key|
        define_method(key) do |handler = nil, &block|
          register_callback(key, handler, &block)
        end
      end

      def register_item_processor(processor = nil, &block)
        callable = processor || block
        validate_callable!(callable, :item_processor)
        @item_processors << callable
        callable
      end

      def callbacks_for(name)
        @callbacks[name.to_sym]&.dup || []
      end

      def item_processors
        @item_processors.dup
      end

      def reset!
        @callbacks.clear
        @item_processors.clear
      end

      private

      def register_callback(key, handler = nil, &block)
        callable = handler || block
        validate_callable!(callable, key)
        key = key.to_sym
        unless CALLBACK_KEYS.include?(key)
          raise ArgumentError, "Unknown event #{key.inspect}"
        end

        @callbacks[key] << callable
        callable
      end

      def validate_callable!(callable, name)
        unless callable.respond_to?(:call)
          raise ArgumentError, "#{name} handler must respond to #call"
        end
      end
    end
  end
end
