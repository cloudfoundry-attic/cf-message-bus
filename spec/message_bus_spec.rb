require "cf_message_bus/message_bus"
require "cf_message_bus/message_bus_factory"
require_relative "support/message_bus_behaviors"
require_relative "support/mock_nats"

module CfMessageBus
  describe MessageBus do
    let(:mock_nats) { MockNATS.new }
    let(:bus_uri) { "some message bus uri" }
    let(:bus) { MessageBus.new(:uri => bus_uri, :logger => logger) }
    let(:msg) { {:foo => "bar"} }
    let(:msg_json) { Yajl::Encoder.encode(msg) }
    let(:logger) { double(:logger, :info => nil) }

    before do
      MessageBusFactory.stub(:message_bus).with(bus_uri).and_return(mock_nats)
      EM.stub(:schedule).and_yield
      EM.stub(:defer).and_yield
      bus.stub(:register_cloud_controller)
    end

    it_behaves_like :a_message_bus

    it 'should get the internal message bus from the factory' do
      MessageBusFactory.should_receive(:message_bus).with(bus_uri).and_return(mock_nats)
      MessageBus.new(:uri => bus_uri)
    end

    describe "subscribing" do
      it 'should subscribe on nats' do
        mock_nats.should_receive(:subscribe).with("foo", {}).and_yield(msg_json, nil)
        bus.subscribe("foo") do |data, inbox|
          data.should == msg
        end
      end

      it 'should handle exceptions in the callback' do
        mock_nats.should_receive(:subscribe).with("foo", {}).and_yield(msg_json, nil)
        logger.should_receive(:error).with(/^exception processing: 'foo'/)
        bus.subscribe("foo") do |data, inbox|
          raise 'hey guys'
        end
      end

      it 'should handle exceptions in json' do
        mock_nats.should_receive(:subscribe).with("foo", {}).and_yield("not json", nil)
        logger.should_receive(:error).with(/^exception parsing json: 'not json'/)
        bus.subscribe("foo") do |data, inbox|
          raise 'hey guys'
        end
      end
    end

    describe "publishing" do
      it 'should publish on nats' do
        mock_nats.should_receive(:publish).with("foo", "bar")
        bus.publish('foo', 'bar')
      end
    end

    context "after nats comes back up" do
      it 'should resubscribe' do
        bus.subscribe("first")
        bus.subscribe("second")
        bus.subscribe("third")

        mock_nats.should_receive(:subscribe).with("first", {})
        mock_nats.should_receive(:subscribe).with("second", {})
        mock_nats.should_receive(:subscribe).with("third", {})

        mock_nats.reconnect!
      end

      it 'should call the recovery callbacks' do
        callback = double(:called => true)
        callback.should_receive(:called)
        bus.recover do
          callback.called
        end

        mock_nats.reconnect!
      end
    end
  end
end
