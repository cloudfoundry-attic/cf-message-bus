require "cf_message_bus/message_bus"
require "cf_message_bus/message_bus_factory"
require_relative "support/message_bus_behaviors"
require_relative "support/mock_nats"

module CfMessageBus
  describe MessageBus do
    let(:mock_nats) { MockNATS.new }
    let(:bus_uri) { "some message bus uri" }
    let(:bus) { MessageBus.new(uri: bus_uri, logger: logger) }
    let(:msg) { {foo: "bar"} }
    let(:msg_json) { JSON.dump(msg) }
    let(:logger) { double(:logger, info: nil) }
    let(:fake_promise) { double(:promise) }

    before do
      MessageBusFactory.stub(:message_bus).with(bus_uri).and_return(mock_nats)
      EM.stub(:schedule).and_yield
      EM.stub(:defer).and_yield
      EM.stub(:schedule_sync).and_yield(fake_promise)
      bus.stub(:register_cloud_controller)
    end

    it_behaves_like :a_message_bus

    it 'should get the internal message bus from the factory' do
      MessageBusFactory.should_receive(:message_bus).with(bus_uri).and_return(mock_nats)
      MessageBus.new(uri: bus_uri)
    end

    describe 'subscribing' do
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

    describe 'publishing' do
      it 'should publish on nats' do
        mock_nats.should_receive(:publish).with("foo", "bar")
        bus.publish('foo', 'bar')
      end

      it 'should pass a nil message straight through' do
        mock_nats.should_receive(:publish).with("foo", nil)
        bus.publish('foo')
      end

      it 'should dump objects to json' do
        mock_nats.should_receive(:publish).with("foo", JSON.dump('foo' => 'bar'))
        bus.publish('foo', {foo: 'bar'})
      end

      it 'should dump arrays to json' do
        mock_nats.should_receive(:publish).with("foo", JSON.dump(%w[foo bar baz]))
        bus.publish('foo', %w[foo bar baz])
      end
    end

    context 'requesting information over the message bus' do
      it 'should schedule onto the EM loop to make the request' do
        EM.should_receive(:schedule_sync).and_yield(fake_promise)
        mock_nats.should_receive(:request).with('foo', 'bar', max: 1)
        bus.request('foo', 'bar')
      end

      it 'should deliver the promise' do
        mock_nats.stub(:request).and_yield('foo')
        fake_promise.should_receive(:deliver).with(%w[foo])
        bus.request('foo')
      end

      it 'should wait to deliver the promise if multiple results are expected' do
        mock_nats.should_receive(:request).with('foo', nil, max: 3).and_yield('foo').and_yield('bar').and_yield('baz')
        fake_promise.should_receive(:deliver).with(%w[foo bar baz])
        bus.request('foo', nil, result_count: 3)
      end

      it 'should timeout the request even if we have not gotted all the results' do
        request_stub = mock_nats.stub(:request)
        request_stub.and_return('request_id')
        request_stub.and_yield('foo').and_yield('bar')
        mock_nats.should_receive(:timeout).with('request_id', 5, expected: 3).and_yield

        fake_promise.should_receive(:deliver).with(%w[foo bar])
        bus.request('foo', nil, result_count: 3, timeout: 5)
      end
    end

    context 'after nats comes back up' do
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
        callback = double(called: true)
        callback.should_receive(:called)
        bus.recover do
          callback.called
        end

        mock_nats.reconnect!
      end
    end
  end
end
