require 'net/http'
require 'logger'
require 'serialport'
require_relative 'lib/control_state'
require_relative 'lib/dispatcher'
require_relative 'lib/timed'

include Timed

serial = SerialPort.new('/dev/tty.usbmodem1441', 9600, 8, 1, SerialPort::NONE)

level = Logger::DEBUG

logger = Logger.new($stdout)
logger.procname = 'main'
logger.level = level

dispatch_logger = Logger.new($stdout)
dispatch_logger.procname = 'dispatch'
dispatch_logger.level = level

dispatcher = Dispatcher.new(logger: dispatch_logger)
threads = []

threads << Thread.new {
  loop {
    raw = serial.gets
    if raw
      ms = timed do
        new_state = ControlState.parse(raw.chomp)
        dispatcher.process(new_state)
      end
      logger.info "#{ms} ms"
    end
  }
}

threads << Thread.new {
  loop {
    # send "we're alive" messages to arduino
    serial.write('1')
    sleep 0.1
  }
}

threads.each { |thr| thr.join }
