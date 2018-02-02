require 'net/http'
require 'logger'
require 'serialport'
require 'optparse'
require_relative '../lib/control_state'
require_relative '../lib/dispatcher'
require_relative '../lib/timed'

include Timed

logger = Logger.new($stdout)
logger.progname = 'main'

dispatch_logger = Logger.new($stdout)
dispatch_logger.progname = 'dispatch'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: main.rb [options]"

  opts.on('-v', '--[no-]verbose', 'Run verbosely') do |o|
    level = o ? Logger::DEBUG : Logger::INFO
    logger.level = level
    dispatch_logger.level = level
  end

  opts.on('-t', '--test-mode', 'Log commands but dont send to telemachus.') do |o|
    options[:test_mode] = o
    if o
      logger.warn "Test mode enabled. No commands will be sent to telemachus."
    end
  end

  opts.on(
    '-d',
    '--device',
    'Specify USB connection to use. (Auto-detect is attempted if this is not set.)' \
      " Example: '--device /dev/tty.usbserial-DN03FAMI'"
  ) do |o|
    options[:device] = o
  end
end.parse!

def detect_usb_serial_device
  candidates = Dir['/dev/tty.usb*']
  candidates.first
end

if options[:device].nil?
  detected = detect_usb_serial_device
  if detected.nil?
    logger.error "Unable to detect USB device, and no --device specified."
    logger.error "Exiting."
    exit 1
  end
  options[:device] = detected
end

logger.info "Connecting to #{options[:device]}"

serial = SerialPort.new(options[:device], 9600, 8, 1, SerialPort::NONE)

dispatcher_options = { logger: dispatch_logger }
dispatcher_options[:send_commands] = false if options[:test_mode]
dispatcher = Dispatcher.new(dispatcher_options)
threads = []

threads << Thread.new {
  loop {
    raw = serial.gets
    if raw
      ms = timed do
        new_state = ControlState.parse(raw.chomp)
        dispatcher.process(new_state)
      end
      logger.debug "dispatch took #{ms} ms"
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


# TODO: handle

# I, [2017-12-18T20:19:44.109027 #40703]  INFO -- dispatch: throttle=0.5
# /Users/alex/.rvm/rubies/ruby-2.4.2/lib/ruby/2.4.0/net/http.rb:906:in `rescue in block in connect': Failed to open TCP connection to 127.0.0.1:8085 (Connection refused - connect(2) for "127.0.0.1" port 8085) (Errno::ECONNREFUSED)
