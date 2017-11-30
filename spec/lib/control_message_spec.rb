require 'spec_helper'
require root.join('lib/control_message.rb')

RSpec.describe ControlMessage, type: :model do
  describe '.parse' do
    it 'extracts throttle setting from first 2 characters' do
      input = '59-0'
      subject = ControlMessage.parse(input)

      expect(subject.read(:throttle)).to eq 59
    end

    it 'extracts autopilot mode from 3rd character' do
      input = '0020'
      subject = ControlMessage.parse(input)
      expect(subject.read(:autopilot_mode)).to eq 'normalplus'

      input = '00-0'
      subject = ControlMessage.parse(input)
      expect(subject.read(:autopilot_mode)).to eq 'smartassoff'
    end

    it 'parses inactive momentary bitmask values as nil' do
      # when these aren't sent by arduino, don't send anything to telemachus
      input = "---0"
      subject = ControlMessage.parse(input)

      subject.class.command_attrs.each do |attr|
        expect(subject.read(attr)).to(eq(nil), "expected :#{attr} to be nil, but it wasn't.")
      end
    end

    it 'parses normal inactive bitmask values as false' do
      # when these aren't set, send false. (tell telemachus "turn this off".)
      input = "---0"
      subject = ControlMessage.parse(input)

      (subject.class.bitmask_attrs - subject.class.command_attrs).each do |attr|
        expect(subject.read(attr)).to(eq(false), "expected :#{attr} to be false, but it wasn't.")
      end
    end

    it 'parses active bitmask values as true' do
      mask = (2 ** 15) - 1
      input = "---#{mask}"
      subject = ControlMessage.parse(input)

      subject.class.bitmask_attrs.each do |attr|
        expect(subject.read(attr)).to(eq(true), "expected :#{attr} to be true, but it wasn't.")
      end
    end
  end

  describe '.valid_attrs' do
    it 'should be the union of value_attrs and bitmask_attrs' do
      expect(described_class.valid_attrs).to eq(described_class.value_attrs + described_class.bitmask_attrs)
    end
  end

  describe '#read' do
    it 'reads desired attribute' do
      subject = ControlMessage.new(action_group_2: true)
      expect(subject.read(:action_group_2)).to eq true
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
      subject = ControlMessage.new(
        throttle: nil,
        autopilot_mode: 'normalminus',
        action_group_9: true
      )

      expect(subject.read_present).to(
        eq(
          autopilot_mode: 'normalminus',
          action_group_9: true
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

  xdescribe '#each' do
    it 'enumerates all attributes' do
      seen_attrs = []

      subject.each { |k, v| seen_attrs << k }

      expect(seen_attrs).to eq described_class.valid_attrs
    end
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

  describe '#merge', focus: true do
    it 'sets attributes of current instance to equal the values of other instance' do
      other = ControlMessage.new(sas: true)

      expect(subject.read(:sas)).to eq nil
      subject.merge!(other)
      expect(subject.read(:sas)).to eq true
    end

    it 'does not overwrite existing values with nils from other' do
      subject.write(:throttle, 78)
      other = ControlMessage.new(throttle: nil)

      expect(subject.read(:throttle)).to eq 78
      subject.merge!(other)
      expect(subject.read(:throttle)).to eq 78
    end

    it 'overwrites current values with values from other' do
      subject.write(:throttle, 78)
      other = ControlMessage.new(throttle: 89)

      expect(subject.read(:throttle)).to eq 78
      subject.merge!(other)
      expect(subject.read(:throttle)).to eq 89
    end
  end
end
