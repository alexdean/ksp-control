require 'spec_helper'
require root.join('lib/dispatcher.rb')

RSpec.describe Dispatcher, type: :model do
  let(:subject) { Dispatcher.new(telemachus_url: 'http://localhost') }
  let(:msg_1) { ControlMessage.new }
  let(:msg_2) { ControlMessage.new }
  let(:msg_3) { ControlMessage.new }

  describe '#push' do
    it 'adds a message to the queue' do
      expect(subject.queue.size).to eq 0

      subject.push(msg_1)

      expect(subject.queue.size).to eq 1
    end
  end

  describe '#start' do
    it 'continually processes the queue' do
      count = 0
      allow(subject).to receive(:process_queue) do
        count += 1
      end

      subject.start
      sleep 0.1
      subject.stop

      expect(count).to be > 1
    end

    it 'uses returned previous value as input for next iteration' do
      expect(subject).to(
        receive(:process_queue)
          .with(ControlMessage.new)
          .and_return(msg_1)
          .ordered
      )
      expect(subject).to(
        receive(:process_queue)
          .with(msg_1)
          .and_return(msg_2)
          .ordered
      )
      expect(subject).to(
        receive(:process_queue)
          .with(msg_2)
          .and_return(msg_3)
          .ordered
      )
      # this will happen repeatedly until process is stopped.
      expect(subject).to(
        receive(:process_queue)
          .with(msg_3)
          .and_return(msg_3)
          .at_least(2).times
      )

      subject.start
      sleep 0.1
      subject.stop
    end
  end

  describe '#process_queue' do
    it 'calls #post with each set of changes' do
      msg_0 = ControlMessage.new
      msg_1 = ControlMessage.new(throttle: 100, autopilot_mode: 2)
      msg_2 = ControlMessage.new(throttle: 70, autopilot_mode: 3)
      msg_3 = ControlMessage.new(throttle: 30, autopilot_mode: 3)

      diff_1_to_0 = msg_1.diff(msg_0)
      diff_2_to_1 = msg_2.diff(msg_1)
      diff_3_to_2 = msg_3.diff(msg_2)

      expect(subject).to receive(:post).with(diff_1_to_0)
      expect(subject).to receive(:post).with(diff_2_to_1)
      expect(subject).to receive(:post).with(diff_3_to_2)

      subject.push msg_1
      subject.push msg_2
      subject.push msg_3

      subject.process_queue(msg_0)
    end

    it 'returns the last queued message' do
      allow(subject).to receive(:post)

      subject.push msg_1
      subject.push msg_2
      subject.push msg_3

      out = subject.process_queue(msg_1)
      expect(out).to eq msg_3
    end

    it 'returns its input if no messages are queued' do
      out = subject.process_queue(msg_1)

      expect(out).to eq msg_1
    end

    it 'does not resend control groups'
  end

  describe '#post' do
    it 'does not send if no changes exist'
  end

  describe '#stop' do
    it 'should be tested'
  end
end
