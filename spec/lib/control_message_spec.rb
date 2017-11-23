require 'spec_helper'
require root.join('lib/control_message.rb')

RSpec.describe ControlMessage, type: :model do
  describe '.parse' do
    it 'extracts data' do
      input = '0013'
      subject = ControlMessage.parse(input)

      expect(subject.action_group).to eq 0
      expect(subject.throttle).to eq 1
      expect(subject.autopilot_mode).to eq 3
    end

    it 'sets nil values' do
      input = '----'
      subject = ControlMessage.parse(input)

      expect(subject.action_group).to eq nil
      expect(subject.throttle).to eq nil
      expect(subject.autopilot_mode).to eq nil
    end
  end
end
