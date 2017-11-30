require 'net/http'
require 'serialport'
require_relative 'lib/control_state'
require_relative 'lib/dispatcher'

serial = SerialPort.new('/dev/tty.usbmodem1441', 9600, 8, 1, SerialPort::NONE)

dispatcher = Dispatcher.new
threads = []

threads << Thread.new {
  loop {
    raw = serial.gets
    if raw
      new_state = ControlState.parse(raw.chomp)
      dispatcher.process(new_state)
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
