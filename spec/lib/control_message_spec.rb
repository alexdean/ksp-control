require 'spec_helper'
require root.join('lib/control_message.rb')

RSpec.describe ControlMessage, type: :model do
  describe '.parse' do
    it 'extracts data' do
      input = '0013'
      subject = ControlMessage.parse(input)

      expect(subject.read(:action_group)).to eq 0
      expect(subject.read(:throttle)).to eq 1
      expect(subject.read(:autopilot_mode)).to eq 3
    end

    it 'sets nil values' do
      input = '----'
      subject = ControlMessage.parse(input)

      expect(subject.read(:action_group)).to eq nil
      expect(subject.read(:throttle)).to eq nil
      expect(subject.read(:autopilot_mode)).to eq nil
    end
  end

  describe '#read' do
    it 'reads desired attribute' do
      subject = ControlMessage.new(action_group: 1)
      expect(subject.read(:action_group)).to eq 1
    end

    it 'raises exception for unknown attribute' do
      subject = ControlMessage.new
      expect {
        subject.read(:foo)
      }.to raise_error(ArgumentError, "unknown attribute :foo")
    end
  end

  describe '#read_present' do
    it 'returns hash of non-nil attributes' do
      subject = ControlMessage.new(action_group: 1, throttle: nil, autopilot_mode: 5)
      expect(subject.read_present).to(
        eq(
          action_group: 1,
          autopilot_mode: 5
        )
      )
    end
  end

  describe '#write' do
    it 'writes an attribute' do
      subject = ControlMessage.new
      subject.write(:throttle, 89)

      expect(subject.read(:throttle)).to eq 89
    end

    it 'raises exception for unknown attribute' do
      subject = ControlMessage.new
      expect {
        subject.write(:foo, 99)
      }.to raise_error(ArgumentError, "unknown attribute :foo")
    end
  end

  describe '#diff' do
    it 'returns a new message with values that dont match the other message' do
      older = ControlMessage.new(
        action_group: nil,
        throttle: 2,
        autopilot_mode: 3
      )
      newer = ControlMessage.new(
        action_group: 1,
        throttle: 2,
        autopilot_mode: 4
      )

      out = newer.diff(older)
      expect(out.read(:action_group)).to eq 1
      expect(out.read(:throttle)).to eq nil
      expect(out.read(:autopilot_mode)).to eq 4
    end

    it 'always returns non-nil action_group' do
      older = ControlMessage.new(
        action_group: 1
      )
      newer = ControlMessage.new(
        action_group: 1
      )

      out = newer.diff(older)
      expect(out.read(:action_group)).to eq 1
    end
  end
end
