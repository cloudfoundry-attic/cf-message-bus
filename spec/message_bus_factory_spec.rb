require "cf_message_bus/message_bus_factory"

module CfMessageBus
  describe MessageBusFactory do
    let(:uri) { "nats://localhost:4222" }
    let(:config) { { servers: uri } }
    let(:client) { double(:client) }
    subject(:get_bus) { MessageBusFactory.message_bus(config) }
    before do
      ::NATS.stub(:connect).and_return(client)
    end

    it { should == client }

    it 'should connect to the uri' do
      ::NATS.should_receive(:connect).with(hash_including(uri: uri))
      get_bus
    end

    it 'should setup infinite retry' do
      ::NATS.should_receive(:connect).with(hash_including(max_reconnect_attempts: -1))
      get_bus
    end

    it 'configures to not shuffle servers (workaround for nats lib bug)' do
      ::NATS.should_receive(:connect).with(hash_including(dont_randomize_servers: false))
      get_bus
    end

    describe 'config' do
      context 'has :uris' do
        let(:config) { { uris: uri } }

        it 'should connect to the uri' do
          ::NATS.should_receive(:connect).with(hash_including(uri: uri))
          get_bus
        end
      end

      context 'has :uri' do
        let(:config) { { uri: uri } }

        it 'should connect to the uri' do
          ::NATS.should_receive(:connect).with(hash_including(uri: uri))
          get_bus
        end
      end

      context 'has :max_reconnect_attempts' do
        let(:config) { { servers: uri, max_reconnect_attempts: 10 } }

        it 'should setup max reconnect attempts' do
          ::NATS.should_receive(:connect).with(hash_including(max_reconnect_attempts: 10))
          get_bus
        end
      end

      context 'has :dont_randomize_servers' do
        let(:config) { { servers: uri, dont_randomize_servers: true } }

        it 'should setup max reconnect attempts' do
          ::NATS.should_receive(:connect).with(hash_including(dont_randomize_servers: true))
          get_bus
        end
      end
    end
  end
end
