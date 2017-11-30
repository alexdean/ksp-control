require 'spec_helper'
require root.join('lib/dispatcher.rb')

RSpec.describe Dispatcher, type: :model do
  describe '#process' do
    # it 'calls #post with each set of changes' do

    #   subject.push msg_1
    #   subject.push msg_2
    #   subject.push msg_3

    #   subject.process_queue(msg_0)
    # end

    it 'posts state changes to telemachus' do
      new_state = ControlState.new(throttle: 100, sas: true)
      diff = new_state.diff(subject.current_state)

      expect(subject).to receive(:post).with(diff)

      subject.process(new_state)
    end

    it 'stores new current state' do
      new_state = ControlState.new(throttle: 100, sas: true)

      allow(subject).to receive(:post)

      subject.process(new_state)

      expect(subject.current_state).to eq new_state
    end

    # once these are sent, we shouldn't send them again
    it 'does not persist commands' do
      new_state = ControlState.new(throttle: 100, sas: true, stage: true)

      allow(subject).to receive(:post)

      subject.process(new_state)

      expect(subject.current_state.read(:stage)).to eq nil
    end
  end

  describe '#post' do
    it 'does not send if no changes exist' do
      expect(Net::HTTP).not_to receive(:get)

      subject.post(ControlState.new)
    end

    it 'formats multiple commands into a single request' do
      expect(Net::HTTP).to(
        receive(:get)
        .with(
          URI('http://127.0.0.1:8085/telemachus/datalink?a=f.rcs%5BTrue%5D&b=f.sas%5BTrue%5D&c=f.light%5BFalse%5D')
        )
      )

      command = ControlState.new(
        rcs: true,
        sas: true,
        lights: false
      )
      subject.post(command)
    end

    it 'sends throttle' do
      expect(Net::HTTP).to(
        receive(:get)
        .with(
          URI('http://127.0.0.1:8085/telemachus/datalink?a=f.setThrottle%5B84%5D')
        )
      )

      command = ControlState.new(throttle: 84)
      subject.post(command)
    end

    it 'sends autopilot mode' do
      expect(Net::HTTP).to(
        receive(:get)
        .with(
          URI('http://127.0.0.1:8085/telemachus/datalink?a=mj.prograde')
        )
      )

      command = ControlState.new(autopilot_mode: 'prograde')
      subject.post(command)
    end

    it 'sends true boolean flags' do
      expect(Net::HTTP).to(
        receive(:get)
        .with(
          URI('http://127.0.0.1:8085/telemachus/datalink?a=f.rcs%5BTrue%5D')
        )
      )

      command = ControlState.new(rcs: true)
      subject.post(command)
    end

    it 'sends false boolean flags' do
      expect(Net::HTTP).to(
        receive(:get)
        .with(
          URI('http://127.0.0.1:8085/telemachus/datalink?a=f.rcs%5BFalse%5D')
        )
      )

      command = ControlState.new(rcs: false)
      subject.post(command)
    end

    it 'triggers commands' do
      expect(Net::HTTP).to(
        receive(:get)
        .with(
          URI('http://127.0.0.1:8085/telemachus/datalink?a=f.stage&b=f.ag5')
        )
      )

      command = ControlState.new(stage: true, action_group_5: true)
      subject.post(command)
    end
  end
end
