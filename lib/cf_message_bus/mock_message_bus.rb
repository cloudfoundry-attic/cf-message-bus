module CfMessageBus
  class MockMessageBus
    attr_reader :published_messages, :published_synchronous_messages

    def initialize(config = {})
      @logger = config[:logger]
      @subscriptions = Hash.new { |hash, key| hash[key] = [] }
      @requests = {}
      @synchronous_requests = {}
      @published_messages = []
      @published_synchronous_messages = []
    end

    def subscribe(subject, opts = {}, &blk)
      @subscriptions[subject] << blk
      subject
    end

    def publish(subject, message = nil, &callback)
      @subscriptions[subject].each { |subscription| subscription.call(message) }

      @published_messages.push({subject: subject, message: message, callback: callback})

      callback.call if callback
    end

    def request(subject, data=nil, options={}, &blk)
      @requests[subject] = blk
      publish(subject, data)
      subject
    end

    def synchronous_request(subject, data=nil, options={})
      @published_synchronous_messages.push(subject: subject, data: data, options: options)
      @synchronous_requests[subject]
    end

    def unsubscribe(subscription_id)
      @subscriptions.delete(subscription_id)
      @requests.delete(subscription_id)
    end

    def recover(&block)
      @recovery = block
    end

    def connected?
      true
    end

    def respond_to_synchronous_request(request_subject, data)
      @synchronous_requests[request_subject] = data
    end

    def respond_to_request(request_subject, data)
      block = @requests.fetch(request_subject) { lambda { |data| nil } }
      block.call(data)
    end

    def do_recovery
      @recovery.call if @recovery
    end

    def clear_published_messages
      @published_messages.clear
    end

    def has_published?(subject)
      @published_messages.find { |message| message[:subject] == subject }
    end

    def has_published_with_message?(subject, message)
      @published_messages.find do |publication|
        publication[:subject] == subject &&
          publication[:message] == message
      end
    end

    def has_requested_synchronous_messages?(subject, data=nil, options={})
      @published_synchronous_messages.find do |publication|
        publication[:subject] == subject &&
          publication[:data] == data &&
          publication[:options] == options
      end
    end
  end
end
