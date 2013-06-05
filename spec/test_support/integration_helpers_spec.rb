module CfMessageBus
  describe IntegrationHelpers do
    include IntegrationHelpers
    describe "start and stop message_bus" do
      it "ensures message bus works" do
        start_message_bus
        expect(message_bus_up?).to be_true

        message_bus.publish "fake", "bar"
        expect(message_bus.request("fake")).to eq "bar"

        stop_message_bus
        expect(message_bus_up?).to be_false
      end
    end

    describe "stop_message_bus"
    describe "kill_message_bus"
    describe "wait_for_message_bus_to_start"
    describe "wait_for_message_bus_to_stop"
  end
end