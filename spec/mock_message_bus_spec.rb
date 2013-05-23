require 'cf_message_bus/mock_message_bus'
require_relative 'support/message_bus_behaviors'

module CfMessageBus
  describe MockMessageBus do
    it_behaves_like :a_message_bus
  end
end