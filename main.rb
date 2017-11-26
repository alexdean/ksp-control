require 'net/http'
require 'serialport'
require_relative 'lib/control_message'
require_relative 'lib/dispatcher'

serial = SerialPort.new('/dev/tty.usbmodem1441', 9600, 8, 1, SerialPort::NONE)

dispatcher = Dispatcher.new(telemachus_url: 'http://localhost')
dispatcher.start

threads = []

threads << Thread.new {
  loop {
    raw = serial.gets
    if raw
      raw.chomp!
      message = ControlMessage.parse(raw)
      dispatcher.push(message)
    end
  }
}

threads << Thread.new {
  loop {
    serial.write('1')
    sleep 0.1
  }
}

threads.each { |thr| thr.join }
dispatcher.stop
