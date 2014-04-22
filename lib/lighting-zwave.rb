require 'zwave'

module NestControl
  class NestZWave
    def initialize
      log = Log4r::Logger['lighting']

      # open a connection to the ZWave controller
      log.info "Initializing ZWave controller on port #{NestConfig[:zwave][:controller][:port]}"
      @controller = nil
      begin
        @controller = ZWave::SerialAPI.new NestConfig[:zwave][:controller][:port]
      rescue Errno::ENOENT
        # TODO: retry later on
        log.error "Unable to initialize ZWave controller, ZWave devices will not function"
        return
      end
      
      # set up a hash of all our devices for later use
      @devices = Hash.new
      NestConfig[:zwave][:devices].each do |device_name, details|
        case details[:type]
          when "switch"
            log.info "Initializing ZWave device #{device_name} as a #{details[:type]} with ID #{details[:id]}"
            @devices[device_name.to_s] = @controller.switch(details[:id])
          else
            log.error "Unable to initialize device #{device_name} as type #{details[:type]} is unknown"
        end
      end
      
      def [](device_name)
        @devices[device_name]
      end
    end
  end
end

NestControl::Handlers.register :lighting, 0, NestControl::NestZWave.new