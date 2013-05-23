module CfMessageBus
  class MockMessageBus
    def initialize(config = {})
      @logger = config[:logger]
      @subscriptions = Hash.new([])
    end

    def subscribe(subject, opts = {}, &blk)
      @subscriptions[subject] << blk
    end

    def publish(subject, message = nil)
      @subscriptions[subject].each do |subscription|
        subscription.call(message)
      end
    end
  end
end
