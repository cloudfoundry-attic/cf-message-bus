require 'cf_message_bus/mock_message_bus'
require_relative 'support/message_bus_behaviors'

module CfMessageBus
  describe MockMessageBus do
    it_behaves_like :a_message_bus

    let(:bus) { MockMessageBus.new }

    it 'should call subscribers inline' do
      received_data = nil

      bus.subscribe("foo") do |data|
        received_data = data
      end
      expect(received_data).to be_nil

      publish_data = 'bar'
      bus.publish("foo", publish_data)
      expect(received_data).to eql(publish_data)
    end

    it 'should symbolize keys to the subscriber' do
      received_data = nil

      bus.subscribe("foo") do |data|
        received_data = data
      end
      expect(received_data).to be_nil

      bus.publish("foo",  { 'foo' => 'bar', 'baz' => 'quux' })
      expect(received_data).to eql({ foo: 'bar', baz: 'quux' })
    end

    it 'should respond to requests' do
      received_data = nil
      bus.request('hey guys') do |data|
        received_data = data
      end
      expect(received_data).to be_nil

      bus.respond_to_request('hey guys', 'foo')
      expect(received_data).to eql('foo')
    end

    it 'should symbolize keys when responding to requests' do
      received_data = nil
      bus.request('hey guys') do |data|
        received_data = data
      end
      expect(received_data).to be_nil

      bus.respond_to_request('hey guys', { 'foo' => 'bar' })
      expect(received_data).to eql({ foo: 'bar' })
    end
  end
end