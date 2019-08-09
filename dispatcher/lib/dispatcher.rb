require 'net/http'
require 'logger'
require_relative './control_state.rb'
require_relative './timed.rb'

# compute state changes and send them to telemachus
#
# @todo: terminology confusion. is a 'command' any instruction sent to
#   telemachus, or is that term only for momentary/valueless instructions
#   like 'stage' or action groups?
class Dispatcher
  include Timed
  attr_reader :current_state

  # @param [String] telemachus_url where to send commands to.
  # @param [CommandState] current_state Current state of the control
  #   panel. Subsequent command differences will be computed from this state.
  # @param [Logger] logger A logger to write output to.
  # @param [boolean] send_commands Should HTTP requests actually be made to
  #   telemachus? Use `false` for integration testing.
  def initialize(
    telemachus_url: 'http://127.0.0.1:8085/telemachus/datalink',
    current_state: nil,
    logger: nil,
    send_commands: true
  )
    @telemachus_url = telemachus_url
    @current_state = current_state || ControlState.new
    @log = logger || Logger.new('/dev/null')
    @send_commands = send_commands

    # CommandState values are subtituted into these strings to build
    # valid telemachus command strings.
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
  # @param [ControlState] an incoming message to process
  def process(command)
    changes = command.diff(current_state)
    sent = post(changes)

    current_state.merge!(command)
    current_state.reset_command_attrs!

    return sent
  end

  def post(changes)
    to_send = changes.read_present
    commands = {}
    url_key = 'a'
    log_msgs = []

    to_send.select { |k, v| !v.nil? }.each do |command_key, command_value|
      log_msgs << "#{command_key}=#{command_value.to_s.gsub(/smartassoff/, 'disabled')}"
      value = case command_value
                when true then 'True'
                when false then 'False'
                else command_value
              end

      template = @command_templates[command_key]
      if template.nil?
        @log.error "ignoring unrecognized command #{command_key}:#{command_value}"
      else
        commands[url_key] = template.gsub(/%s/, value.to_s)
      end

      url_key = url_key.succ
    end

    return if commands.size == 0

    uri = URI(@telemachus_url)
    uri.query = URI.encode_www_form(commands)

    @log.info log_msgs.join(', ')

    # TODO: detect & report errors
    # yes. we're changing state with a GET request.
    # telemachus don't need no stinking REST.
    ms = timed do
      begin
        Net::HTTP.get uri if @send_commands
      # don't die if telemachus isn't listening yet.
      rescue => e
        @log.error { "   #{uri} #{e.message} (#{e.class})" }
      end
    end

    @log.debug {  "   #{uri} (#{ms}ms)" }
    if !@send_commands
      @log.warn { "   not sent due to send_commands:false"}
    end

    true
  end
end
