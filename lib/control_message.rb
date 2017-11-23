# a message from the control board. a data object.
class ControlMessage
  attr_reader :action_group, :throttle, :autopilot_mode

  def self.parse(message_str)
    positions = {
      action_group: 0,
      throttle: 1..2,
      autopilot_mode: 3
    }

    args = {}
    positions.each do |key, pos|
      val = message_str[pos]
      val = val[0] == '-' ? nil : val.to_i

      args[key] = val
    end

    new(args)
  end

  def initialize(action_group:, throttle:, autopilot_mode:)
    @action_group = action_group
    @throttle = throttle
    @autopilot_mode = autopilot_mode
  end
end

