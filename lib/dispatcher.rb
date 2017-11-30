require 'net/http'
require_relative './control_state.rb'

# compute state changes and send them to telemachus
class Dispatcher
  attr_reader :current_state

  def initialize(
    telemachus_url: 'http://127.0.0.1:8085/telemachus/datalink',
    current_state: nil
  )
    @telemachus_url = telemachus_url
    @current_state = current_state || ControlState.new
    @command_templates = {
      throttle: 'f.setThrottle[%s]',
      autopilot_mode: 'mj.%s',
      stage: 'f.stage',
      sas: 'f.sas[%s]',
      rcs: 'f.rcs[%s]',
      lights: 'f.light[%s]',
      gear: 'f.gear[%s]',
      brakes: 'f.brake[%s]',
      action_group_1: 'f.ag1',
      action_group_2: 'f.ag2',
      action_group_3: 'f.ag3',
      action_group_4: 'f.ag4',
      action_group_5: 'f.ag5',
      action_group_6: 'f.ag6',
      action_group_7: 'f.ag7',
      action_group_8: 'f.ag8',
      action_group_9: 'f.ag9'
    }
  end

  # examine a current state message and post any changes to telemachus
  #
  # @param [ControlMessage] an incoming message to process
  def process(command)
    changes = command.diff(current_state)
    post(changes)
    current_state.merge!(command)
    current_state.reset_command_attrs!
  end

  def post(changes)
    to_send = changes.read_present
    return if !to_send.any? { |k, v| !v.nil? }

    commands = {}
    url_key = 'a'
    to_send.select { |k, v| !v.nil? }.each do |command_key, command_value|
      value = case command_value
                when true then 'True'
                when false then 'False'
                else command_value
              end
      # TODO log.info "#{command_key}: #{value}"
      # gsub('smartassoff', 'disabled')
      commands[url_key] = @command_templates[command_key].gsub(/%s/, value.to_s)
      url_key = url_key.succ
    end

    uri = URI(@telemachus_url)
    uri.query = URI.encode_www_form(commands)

    # yes. we're changing state with a GET request.
    # telemachus don't need no stinking REST.
    Net::HTTP.get uri
    # TODO: detect & report errors
  end
end
