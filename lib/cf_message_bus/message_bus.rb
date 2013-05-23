require "eventmachine"
require "eventmachine/schedule_sync"
require "steno"

module CfMessageBus
  class MessageBus
    def initialize(config)
      @logger = config[:logger]
      @internal_bus = MessageBusFactory.message_bus(config[:uri])
      @subscriptions = {}
      @internal_bus.on_reconnect { start_internal_bus_recovery }
      @recovery_callback = lambda {}
    end

    def subscribe(subject, opts = {}, &blk)
      @subscriptions[subject] = [opts, blk]

      subscribe_on_reactor(subject, opts) do |payload, inbox|
        EM.defer do
          begin
            blk.yield(payload, inbox)
          rescue => e
            @logger.error "exception processing: '#{subject}' '#{payload}'"
          end
        end
      end
    end

    def publish(subject, message = nil)
      unless message.nil? || message.is_a?(String)
        message = JSON.dump(message)
      end

      EM.schedule do
        internal_bus.publish(subject, message)
      end
    end

    def recover(&block)
      @recovery_callback = block
    end

    private

    attr_reader :internal_bus

    def start_internal_bus_recovery
      EM.defer do
        @logger.info("Reconnected to internal_bus.")

        @recovery_callback.call

        @subscriptions.each do |subject, options|
          @logger.info("Resubscribing to #{subject}")
          subscribe(subject, options[0], &options[1])
        end
      end
    end

    def request(subject, data = nil, opts = {})
      expected = opts[:expected] || 1
      timeout = opts[:timeout] || -1

      return [] if expected <= 0

      response = EM.schedule_sync do |promise|
        results = []

        sid = internal_bus.request(subject, data, :max => expected) do |msg|
          results << msg
          promise.deliver(results) if results.size == expected
        end

        if timeout >= 0
          internal_bus.timeout(sid, timeout, :expected => expected) do
            promise.deliver(results)
          end
        end
      end

      response
    end

    def subscribe_on_reactor(subject, opts = {}, &blk)
      EM.schedule do
        internal_bus.subscribe(subject, opts) do |msg, inbox|
          process_message(msg, inbox, &blk)
        end
      end
    end

    def process_message(msg, inbox, &blk)
      payload = JSON.parse(msg, :symbolize_keys => true)
      blk.yield(payload, inbox)
    rescue => e
      @logger.error "exception parsing json: '#{msg}' '#{e}'"
    end
  end
end