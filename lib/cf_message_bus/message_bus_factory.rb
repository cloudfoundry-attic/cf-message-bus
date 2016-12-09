require 'nats/client'

module CfMessageBus
  class MessageBusFactory
    def self.message_bus(config)
      ::NATS.connect(
        uri: config[:servers] || config[:uris] || config[:uri],
        max_reconnect_attempts: config[:max_reconnect_attempts] || -1,
        dont_randomize_servers: config[:dont_randomize_servers] || false,
      )
    end
  end
end
