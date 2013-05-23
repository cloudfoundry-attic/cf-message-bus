module CfMessageBus
  class MockMessageBus
    def initialize(config)
      @config = config
      @nats = config[:nats] || MockNATS
    end

    def subscribe(subject, opts = {}, &blk)
    end

    def publish(subject, message = nil)
    end
  end
end
