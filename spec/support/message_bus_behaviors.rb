require "cf_message_bus/message_bus_factory"
require_relative "mock_nats"

shared_examples :a_message_bus do
  describe "a message bus interface" do
    let(:bus_uri) { "uri://uri" }
    let(:config) { { :uri => bus_uri } }
    subject(:message_bus) { described_class.new(config) }

    before do
      CfMessageBus::MessageBusFactory.stub(:message_bus).with(bus_uri).and_return(CfMessageBus::MockNATS.new)
    end

    it 'should be able to subscribe' do
      message_bus.subscribe('thingy', { :some_opts => 'stuff' }) do
        raise 'should not be called here!'
      end
    end

    it 'should be able to subscribe without options' do
      message_bus.subscribe('thingy') do
        raise 'should not be called here!'
      end
    end

    it 'should be able to publish' do
      message_bus.publish('stuff', 'with a message')
    end

    it 'should be able to publish without a message' do
      message_bus.publish('stuff')
    end
  end
end