require 'thread'
require_relative './control_message.rb'

class Dispatcher
  attr_reader :queue

  def initialize(telemachus_url:)
    @telemachus_url = telemachus_url
    @queue = Queue.new
  end

  def push(message)
    @queue << message
  end

  # read queue until its empty
  # accumulate all changes. action_group must be accumulated differently.
  # for all others, last-change-wins
  # when queue is empty, build query string & send.
  def start
    @thread = Thread.new {
      current_state = ControlMessage.new

      loop do
        current_state = process_queue(current_state)
      end
    }
  end

  # send all queued messages to telemachus
  #
  # @param [ControlMessage] the state which was last sent (only changes are sent)
  # @return [ControlMessage] the state we just sent
  def process_queue(previous)
    # TODO: add accumulator step if this queue gets full.
    # TODO: log queue length?
    while !@queue.empty? do
      current = @queue.pop
      changes = current.diff(previous)
      post(changes)
      previous = current
    end

    previous
  end

  def post(to_send)
    to_send.read_present

    if to_send.any? { |k, v| !v.nil? }
      # now translate hash key values into telemachus keys
      # translate hash values into telemachus values
      # send post to telemachus
      # log request & response
    end
  end

  def stop
    @thread.exit
    @thread.join
  end
end
