# a message from the control board. a data object.
class ControlMessage
  # create a ControlMessage from a raw message string
  #
  # ## format
  #
  #   throttle: first 2 characters. '00' - '99'
  #   autopilot mode: 3rd character. '-' for 'disabled'
  #   remaining digits: bitmask for all switches & other boolean values
  #     order specified in .bitmask_attrs
  def self.parse(message_str)
    args = {}

    args[:throttle] = message_str[0..1].to_i

    args[:autopilot_mode] = case message_str[2]
                               # these must all be valid telemachus 'mj.' commands
                               when '0' then 'prograde'
                               when '1' then 'retrograde'
                               when '2' then 'normalplus'
                               when '3' then 'normalminus'
                               when '4' then 'radialplus'
                               when '5' then 'radialminus'
                               when '6' then 'targetplus'
                               when '7' then 'targetminus'
                               when '8' then 'node'
                               else 'smartassoff'
                             end

    bitmask = message_str[3..-1].to_i

    bitmask_attrs.each_with_index do |attr, idx|
      # false: set value to false. nil: don't send value.
      negative = command_attrs.include?(attr) ? nil : false

      args[attr] = ((bitmask & (1 << idx)) != 0) ? true : negative
    end

    new(args)
  end

  def self.value_attrs
    %i[
      throttle
      autopilot_mode
    ]
  end

  # the order here must match the order of bits set by arduino
  def self.bitmask_attrs
    %i[
      stage
      sas
      rcs
      lights
      gear
      brakes
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

  # these are booleans which may be set once
  # but should not retain that setting, and should revert to false
  # after being dispatched to telemachus.
  def self.command_attrs
    %i[
      stage
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
    value_attrs + bitmask_attrs
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

  # TODO: unused?
  # if used... do we enumerate all values or only the non-nil ones?
  # probably all? (more flexible. client can discard nils if it wants to.)
  # def each
  #   @attrs.each do |key, value|
  #     yield key, value
  #   end
  # end

  # does this instance have the same attribute values as the other?
  #
  # @param [ControlMessage] other
  # @return [boolean]
  def ==(other)
    self.class.valid_attrs.each do |attr|
      return false if read(attr) != other.read(attr)
    end
    true
  end

  # sets attributes of current instance equal to the non-nil values of other instance
  #
  # @param [ControlMessage] other
  # @return [ControlMessage] self
  def merge!(other)
    other.read_present.each do |k, v|
      write(k, v)
    end

    self
  end

  # set all momentary attributes back to false.
  def reset_command_attrs!
    self.class.command_attrs.each do |attr|
      write(attr, false)
    end
  end

  private

  def raise_if_invalid!(attr)
    if !self.class.valid_attrs.include?(attr)
      raise ArgumentError, "unknown attribute :#{attr}"
    end
  end
end

