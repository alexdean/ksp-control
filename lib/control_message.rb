# a message from the control board. a data object.
class ControlMessage

  NO_VALUE = '-'

  def self.parse(message_str)
    args = {}
    mapping.each do |key, pos|
      val = message_str[pos]
      val = val[0] == NO_VALUE ? nil : val.to_i

      args[key] = val
    end

    action_group = message_str[0]
    if action_group != NO_VALUE
      args["action_group_#{action_group}".to_sym] = 1
    end

    new(args)
  end

  # describes how to map from raw message strings to attribute values
  #
  # @return [Hash<Symbol,Integer,Range>]
  def self.mapping
    {
      throttle: 1..2,
      autopilot_mode: 3
    }
  end

  def self.valid_attrs
    mapping.keys + [
      :action_group_1,
      :action_group_2,
      :action_group_3,
      :action_group_4,
      :action_group_5,
      :action_group_6,
      :action_group_7,
      :action_group_8,
      :action_group_9,
    ]
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

