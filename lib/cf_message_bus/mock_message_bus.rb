module CfMessageBus
  class MockMessageBus
    def initialize(config = {})
      @logger = config[:logger]
      @subscriptions = Hash.new([])
      @requests = {}
    end

    def subscribe(subject, opts = {}, &blk)
      @subscriptions[subject] << blk
    end

    def publish(subject, message = nil)
      @subscriptions[subject].each do |subscription|
        subscription.call(symbolize_keys(message))
      end
    end

    def request(subject, data=nil, opts={}, &blk)
      @requests[subject] = blk
    end

    def respond_to_request(request_subject, data)
      block = @requests.fetch(request_subject) { raise "No request for #{request_subject}" }
      block.call(symbolize_keys(data))
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
