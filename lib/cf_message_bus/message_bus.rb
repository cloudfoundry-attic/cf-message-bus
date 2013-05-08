require "yajl/json_gem"
require "eventmachine"
require "eventmachine/schedule_sync"
require "steno"

module CfMessageBus
  class MessageBus
    class << self
      def configure(config)
        return @instance if @instance

        @instance = new(config)
        @instance.register_components
        @instance.register_routes

        self
      end

      def publish(*args)
        @instance.publish(*args)
        self
      end

      def subscribe(*args)
        @instance.subscribe(*args)
        self
      end

      def config
        p [:instance, @instance]

        @instance.config
        self
      end
    end

    private

    attr_reader :subscriptions, :nats, :config

    def initialize(config)
      @config = config
      @nats = config[:nats] || NATS
      @subscriptions = {}
      @recovering = false
      @component = config[:component]
    end

    def register_components
      # TODO: put useful metrics in varz
      # TODO: subscribe to the two DEA channels
      nats.on_error do
        unless @recovering
          @recovering = true
          logger.error("NATS connection failed. Starting nats recovery")
          update_nats_varz(Time.now)
          start_nats_recovery
        end
      end

      EM.schedule do
        nats.start(:uri => config[:nats_uri]) do
          logger.info("Connected to NATS")
          register_cloud_controller
          update_nats_varz(nil)
        end
      end
    end

    def start_nats_recovery
      EM.defer do
        nats.wait_for_server(URI(config[:nats_uri]), Float::INFINITY)
        nats.start(:uri => config[:nats_uri]) do
          logger.info("Reconnected to NATS.")

          update_nats_varz(nil)
          register_routes

          @subscriptions.each do |subject, options|
            logger.info("Resubscribing to #{subject}")
            subscribe(subject, options[0], &options[1])
          end
        end
        @recovering = false
      end
    end

    def register_routes
      EM.schedule do
        # TODO: blacklist api2 in legacy CC
        # TODO: Yajl should probably also be injected
        router_register_message = Yajl::Encoder.encode({
          :host => @config[:bind_address],
          :port => config[:port],
          :uris => config[:external_domain],
          :tags => {:component => "CloudController"},
        })

        nats.publish("router.register", router_register_message)

        # Broadcast when a router restarts
        nats.subscribe("router.start") do
          nats.publish("router.register", router_register_message)
        end
      end
    end

    def subscribe(subject, opts = {}, &blk)
      @subscriptions[subject] = [opts, blk]

      subscribe_on_reactor(subject, opts) do |payload, inbox|
        EM.defer do
          begin
            # OK so we're always calling with arity two
            # NATS does a switch on blk.arity
            # we might do it if we are propelled to supply a lambda here...
            blk.yield(payload, inbox)
          rescue => e
            logger.error "exception processing: '#{subject}' '#{payload}'"
          end
        end
      end
    end

    def publish(subject, message = nil)
      EM.schedule do
        nats.publish(subject, message)
      end
    end

    def request(subject, data = nil, opts = {})
      opts ||= {}
      expected = opts[:expected] || 1
      timeout = opts[:timeout] || -1

      return [] if expected <= 0

      response = EM.schedule_sync do |promise|
        results = []

        sid = nats.request(subject, data, :max => expected) do |msg|
          results << msg
          promise.deliver(results) if results.size == expected
        end

        if timeout >= 0
          nats.timeout(sid, timeout, :expected => expected) do
            promise.deliver(results)
          end
        end
      end

      response
    end

    def register_cloud_controller
      @component.register(
        :type => 'CloudController',
        :host => @config[:bind_address],
        :index => config[:index],
        :config => config,
      # leaving the varz port / user / pwd blank to be random
      )
    end

    def subscribe_on_reactor(subject, opts = {}, &blk)
      EM.schedule do
        nats.subscribe(subject, opts) do |msg, inbox|
          process_message(msg, inbox, &blk)
        end
      end
    end

    def process_message(msg, inbox, &blk)
      payload = Yajl::Parser.parse(msg, :symbolize_keys => true)
      blk.yield(payload, inbox)
    rescue => e
      logger.error "exception processing: '#{msg}' '#{e}'"
    end

    def logger
      @logger ||= Steno.logger("cc.mbus")
    end

    def update_nats_varz(value)
      @component.varz.synchronize do
        @component.varz[:nats_downtime] = value
      end
    end
  end
end