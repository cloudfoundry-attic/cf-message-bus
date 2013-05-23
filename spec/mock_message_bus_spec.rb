require 'cf_message_bus/mock_message_bus'
require_relative 'support/message_bus_behaviors'

module CfMessageBus
  describe MockMessageBus do
    it_behaves_like :a_message_bus

    it 'should call subscribers inline' do
      publish_data = {:foo => 'bar', :baz => 'quux'}
      bus = MockMessageBus.new({})
      bus.subscribe("foo") do |data|
        expect(data).to eql(publish_data)
        raise "called callback"
      end

      expect {
        bus.publish("foo", publish_data)
      }.to raise_error(/called callback/)
    end
  end
end