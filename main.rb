require 'net/http'
require 'serialport'
require_relative 'lib/control_message'

serial = SerialPort.new('/dev/tty.usbmodem1441', 9600, 8, 1, SerialPort::NONE)

threads = []

threads << Thread.new {
  loop {
    message = serial.gets
    if message
      message.chomp!
      puts message
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
