# a message from the control board. a data object.
class ControlMessage

  NO_VALUE = '-'

  # create a ControlMessage from a raw message string
  #
  # ## format
  #
  #   throttle: first 2 characters. '-' for 'disabled'
  #   autopilot mode: 3rd character. '-' for 'disabled'
  #   remaining digits: bitmask for all switches & other boolean values
  def self.parse(message_str)
    args = {}
    value_attrs.each do |key, pos|
      val = message_str[pos]
      val = val[0] == NO_VALUE ? nil : val.to_i

      args[key] = val
    end

    bitmask = message_str[3..-1].to_i
    bitmask_attrs.each_with_index do |attr, idx|
      args[attr] = ((bitmask & (1 << idx)) != 0)
    end

    new(args)
  end

  def self.value_attrs
    # f.setThrottle[0.0] / f.setThrottle[1.0]
    #
    # mj.prograde
    # mj.retrograde
    # mj.normalplus
    # mj.normalminus
    # mj.radialplus
    # mj.radialminus
    # mj.targetplus
    # mj.targetminus
    {
      throttle: 0..1,
      autopilot_mode: 2
    }
  end

  def self.bitmask_attrs
    # f.stage
    # f.sas[True]
    # f.rcs[True]
    # f.light[True]
    # f.gear[True]
    # f.brake[True]
    # f.ag1
    # f.ag2
    # f.ag3
    # f.ag4
    # f.ag5
    # f.ag6
    # f.ag7
    # f.ag8
    # f.ag9
    %i[
      stage
      sas_enable
      rcs_enable
      lights_enable
      gear_enable
      brakes_enable
      action_group_1
      action_group_2
      action_group_3
      action_group_4
      action_group_5
      action_group_6
      action_group_7
      action_group_8
      action_group_9
    ]
  end

  def self.valid_attrs
    value_attrs.keys + bitmask_attrs
  end

  def initialize(attrs = {})
    @attrs = attrs
  end

  # read the value of a given attribute
  #
  # raises ArgumentError if an unknown attribute is requested
  #
  # @return [Integer,boolean,nil]
  def read(attr)
    raise_if_invalid!(attr)
    @attrs[attr]
  end

  # TODO: is it right to filter out nils? (how do we send "turn this off?")
  # nil means "no change". so we don't send those.
  # "turn this off" is a '0'
  def read_present
    @attrs.select { |k,v| !v.nil? }
  end

  # write a value
  #
  # @return the newly set value
  def write(attr, value)
    raise_if_invalid!(attr)
    @attrs[attr] = value
  end

  # return a new message containing only the fields which differ from
  # other_message. (all values which match will be nil.)
  #
  # @param [ControlMessage] other_message
  # @return ControlMessage
  def diff(other_message)
    out = self.class.new

    self.class.valid_attrs.each do |attr|
      ours = read(attr)
      theirs = other_message.read(attr)

      if ours != theirs
        out.write(attr, ours)
      end
    end

    out
  end

  def each
    @attrs.each do |key, value|
      yield key, value
    end
  end

  def ==(other)
    self.class.valid_attrs.each do |attr|
      return false if read(attr) != other.read(attr)
    end
    true
  end

  private

  def raise_if_invalid!(attr)
    if !self.class.valid_attrs.include?(attr)
      raise ArgumentError, "unknown attribute :#{attr}"
    end
  end
end

