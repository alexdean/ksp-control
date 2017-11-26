require 'spec_helper'
require root.join('lib/control_message.rb')

RSpec.describe ControlMessage, type: :model do
  describe '.parse' do
    it 'extracts data' do
      input = '2013'
      subject = ControlMessage.parse(input)

      expect(subject.read(:action_group_2)).to eq 1
      expect(subject.read(:throttle)).to eq 1
      expect(subject.read(:autopilot_mode)).to eq 3
    end

    it 'sets nil values' do
      input = '----'
      subject = ControlMessage.parse(input)

      expect(subject.read(:action_group_1)).to eq nil
      expect(subject.read(:throttle)).to eq nil
      expect(subject.read(:autopilot_mode)).to eq nil
    end
  end

  describe '#read' do
    it 'reads desired attribute' do
      subject = ControlMessage.new(action_group_2: 1)
      expect(subject.read(:action_group_2)).to eq 1
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
      subject = ControlMessage.new(action_group_9: 1, throttle: nil, autopilot_mode: 5)
      expect(subject.read_present).to(
        eq(
          action_group_9: 1,
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
        action_group_3: nil,
        throttle: 2,
        autopilot_mode: 3
      )
      newer = ControlMessage.new(
        action_group_3: 1,
        throttle: 2,
        autopilot_mode: 4
      )

      out = newer.diff(older)
      expect(out.read(:action_group_3)).to eq 1
      expect(out.read(:throttle)).to eq nil
      expect(out.read(:autopilot_mode)).to eq 4
    end

    xit 'always returns non-nil action_group' do
      older = ControlMessage.new(
        action_group_5: 1
      )
      newer = ControlMessage.new(
        action_group_5: 1
      )

      out = newer.diff(older)
      expect(out.read(:action_group)).to eq 1
    end
  end

  describe '#each' do
    it 'enumerates all attributes'
  end

  describe '#==' do
    it 'is true if instances have the same attribute values' do
      this = ControlMessage.new(throttle: 99)
      that = ControlMessage.new(throttle: 99)

      expect(this == that).to eq true
    end

    it 'is false if instance have any differences' do
      this = ControlMessage.new(throttle: 99)
      that = ControlMessage.new(throttle: 98)
      expect(this == that).to eq false

      this = ControlMessage.new(throttle: 99, autopilot_mode: 2)
      that = ControlMessage.new(throttle: 99, autopilot_mode: 4)
      expect(this == that).to eq false

      this = ControlMessage.new(throttle: 99, autopilot_mode: nil)
      that = ControlMessage.new(throttle: 99, autopilot_mode: 4)
      expect(this == that).to eq false
    end
  end
end
