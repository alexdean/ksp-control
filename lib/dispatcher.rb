require 'net/http'
require 'logger'
require_relative './control_state.rb'

# compute state changes and send them to telemachus
class Dispatcher
  attr_reader :current_state

  def initialize(
    telemachus_url: 'http://127.0.0.1:8085/telemachus/datalink',
    current_state: nil,
    logger: nil
  )
    @telemachus_url = telemachus_url
    @current_state = current_state || ControlState.new
    @log = logger || Logger.new('/dev/null')
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
    log = []
    to_send.select { |k, v| !v.nil? }.each do |command_key, command_value|
      log << "#{command_key}=#{command_value.to_s.gsub(/smartassoff/, 'disabled')}"
      value = case command_value
                when true then 'True'
                when false then 'False'
                else command_value
              end
      commands[url_key] = @command_templates[command_key].gsub(/%s/, value.to_s)
      url_key = url_key.succ
    end

    return if commands.size == 0



    uri = URI(@telemachus_url)
    uri.query = URI.encode_www_form(commands)

    @log.info log.join(', ')

    # TODO: detect & report errors
    # yes. we're changing state with a GET request.
    # telemachus don't need no stinking REST.
    ms = timed do
      Net::HTTP.get uri
    end
    @log.debug { "   #{uri} (#{ms}ms)" }

    true
  end

  private

  def timed
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    ended_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ((ended_at - started_at) * 1000).round
  end
end
