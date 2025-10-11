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

    attr_reader :http, :scrapers, :retention, :events, :models, :realtime

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
      @models = Models.new
      @realtime = RealtimeSettings.new
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

    class RealtimeSettings
      VALID_ADAPTERS = %i[solid_cable redis async].freeze

      attr_reader :adapter, :solid_cable
      attr_accessor :redis_url

      def initialize
        reset!
      end

      def adapter=(value)
        value = value&.to_sym
        unless VALID_ADAPTERS.include?(value)
          raise ArgumentError, "Unsupported realtime adapter #{value.inspect}"
        end

        @adapter = value
      end

      def reset!
        @solid_cable = SolidCableOptions.new
        @redis_url = nil
        self.adapter = :solid_cable
      end

      def solid_cable=(options)
        solid_cable.assign(options)
      end

      def action_cable_config
        case adapter
        when :solid_cable
          solid_cable.to_h.merge(adapter: "solid_cable")
        when :redis
          config = { adapter: "redis" }
          config[:url] = redis_url if redis_url.present?
          config
        when :async
          { adapter: "async" }
        else
          {}
        end
      end

      class SolidCableOptions
        attr_accessor :polling_interval,
          :message_retention,
          :autotrim,
          :silence_polling,
          :use_skip_locked,
          :trim_batch_size,
          :connects_to

        def initialize
          reset!
        end

        def assign(options)
          return unless options.respond_to?(:each)

          options.each do |key, value|
            setter = "#{key}="
            public_send(setter, value) if respond_to?(setter)
          end
        end

        def reset!
          @polling_interval = "0.1.seconds"
          @message_retention = "1.day"
          @autotrim = true
          @silence_polling = true
          @use_skip_locked = true
          @trim_batch_size = nil
          @connects_to = nil
        end

        def to_h
          {
            polling_interval: polling_interval,
            message_retention: message_retention,
            autotrim: autotrim,
            silence_polling: silence_polling,
            use_skip_locked: use_skip_locked,
            trim_batch_size: trim_batch_size,
            connects_to: connects_to
          }.compact
        end
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

    class Models
      MODEL_KEYS = {
        source: :source,
        item: :item,
        fetch_log: :fetch_log,
        scrape_log: :scrape_log,
        item_content: :item_content
      }.freeze

      attr_accessor :table_name_prefix

      def initialize
        @table_name_prefix = "feed_monitor_"
        @definitions = MODEL_KEYS.transform_values { ModelDefinition.new }
      end

      MODEL_KEYS.each do |method_name, key|
        define_method(method_name) { @definitions[key] }
      end

      def for(name)
        key = name.to_sym
        definition = @definitions[key]
        raise ArgumentError, "Unknown model #{name.inspect}" unless definition

        definition
      end
    end

    class ModelDefinition
      attr_reader :validations

      def initialize
        @concern_definitions = []
        @validations = []
      end

      def include_concern(concern = nil, &block)
        definition = ConcernDefinition.new(concern, block)
        unless @concern_definitions.any? { |existing| existing.signature == definition.signature }
          @concern_definitions << definition
        end

        definition.return_value
      end

      def each_concern
        return enum_for(:each_concern) unless block_given?

        @concern_definitions.each do |definition|
          yield definition.signature, definition.resolve
        end
      end

      def validate(handler = nil, **options, &block)
        callable =
          if block
            block
          elsif handler.respond_to?(:call) && !handler.is_a?(Symbol) && !handler.is_a?(String)
            handler
          elsif handler.is_a?(Symbol) || handler.is_a?(String)
            handler.to_sym
          else
            raise ArgumentError, "Invalid validation handler #{handler.inspect}"
          end

        validation = ValidationDefinition.new(callable, options)
        @validations << validation
        validation
      end

      private

      class ConcernDefinition
        attr_reader :signature

        def initialize(concern, block)
          @resolver = build_resolver(concern, block)
          @signature = build_signature(concern, block)
          @return_value = determine_return_value(concern, block)
        end

        def resolve
          @resolved ||= @resolver.call
        end

        def return_value
          @return_value
        end

        private

        def build_resolver(concern, block)
          if block
            mod = Module.new(&block)
            -> { mod }
          elsif concern.is_a?(Module)
            -> { concern }
          elsif concern.respond_to?(:to_s)
            constant_name = concern.to_s
            lambda do
              constant_name.constantize
            rescue NameError => error
              raise ArgumentError, error.message
            end
          else
            raise ArgumentError, "Invalid concern #{concern.inspect}"
          end
        end

        def build_signature(concern, block)
          if block
            [:anonymous_module, block.object_id]
          elsif concern.is_a?(Module)
            [:module, concern.object_id]
          else
            [:constant, concern.to_s]
          end
        end

        def determine_return_value(concern, block)
          if block
            resolve
          elsif concern.is_a?(Module)
            concern
          else
            concern
          end
        end
      end
    end

    class ValidationDefinition
      attr_reader :handler, :options

      def initialize(handler, options)
        @handler = handler
        @options = options
      end

      def signature
        handler_key =
          case handler
          when Symbol
            [:symbol, handler]
          when String
            [:symbol, handler.to_sym]
          else
            [:callable, handler.object_id]
          end

        [handler_key, options]
      end

      def symbol?
        handler.is_a?(Symbol) || handler.is_a?(String)
      end
    end
  end
end
