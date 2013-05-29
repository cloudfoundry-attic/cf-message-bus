module CfMessageBus
  class MockMessageBus
    def initialize(config = {})
      @logger = config[:logger]
      @subscriptions = Hash.new { |hash, key| hash[key] = [] }
      @requests = {}
    end

    def subscribe(subject, opts = {}, &blk)
      @subscriptions[subject] << blk
      subject
    end

    def publish(subject, message = nil)
      @subscriptions[subject].each do |subscription|
        subscription.call(symbolize_keys(message))
      end
    end

    def request(subject, data=nil, options={}, &blk)
      @requests[subject] = blk
      publish(subject, data)
      subject
    end

    def synchronous_request(subject, data=nil, options={})
    end

    def unsubscribe(subscription_id)
      @subscriptions.delete(subscription_id)
      @requests.delete(subscription_id)
    end

    def recover(&block)
      @recovery = block
    end

    def respond_to_request(request_subject, data)
      block = @requests.fetch(request_subject) { lambda { |data| nil } }
      block.call(symbolize_keys(data))
    end

    def do_recovery
      @recovery.call if @recovery
    end

    private

    def symbolize_keys(hash)
      return hash unless hash.is_a?(Hash)
      hash.inject({}) do |memo, (key, value)|
        memo[key.to_sym] = symbolize_keys(value)
        memo
      end
    end
  end
end
