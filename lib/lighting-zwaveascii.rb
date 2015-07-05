require 'zwaveascii'

module NestControl
  class NestZWave
    def initialize
      log = Log4r::Logger['lighting']
      
      # TODO: controller being the rs232 box and controllers beng ZWave controllers is confusing
      # open a connection to the ZWave controller
      log.info "Initializing ZWave controller on port #{NestConfig[:zwave][:controller][:port]}"
      @controller = nil
      begin
        @controller = ZWave::ASCII.new NestConfig[:zwave][:controller][:port], 115200
	@controller.debug = true
      rescue Errno::ENOENT
        # TODO: retry later on
        log.error "Unable to initialize ZWave controller, ZWave devices will not function"
        return
      end

      # set up a hash of all our devices for later use
      @devices = Hash.new
      @controllers = Hash.new
      NestConfig[:zwave][:devices].each do |device_name, details|
        case details[:type]
          when "switch"
            log.info "Initializing ZWave device #{device_name} as a #{details[:type]} with ID #{details[:id]}"
            @devices[device_name.to_s] = @controller.switch(details[:id])
          when "dimmer"
            log.info "Initializing ZWave device #{device_name} as a #{details[:type]} with ID #{details[:id]}"
            @devices[device_name.to_s] = @controller.dimmer(details[:id])
	  when "scene_controller"
	    log.info "Initializing ZWave device #{device_name} as a #{details[:buttons].count}-button #{details[:type]} with ID #{details[:id]}"
	    @controllers[details[:id]] = details[:buttons]
          when "door_lock"
            log.info "Initializing ZWave device #{device_name} as a #{details[:type]} with ID #{details[:id]}"
            @devices[device_name.to_s] = @controller.door_lock(details[:id])
          else
            log.error "Unable to initialize device #{device_name} as type #{details[:type]} is unknown"
        end
      end
      
      def [](device_name)
        @devices[device_name]
      end
     
      def devices
        @devices
      end

      def reset
        @controller.abort
      end

      # get eventmachine to poll for events
      CoreEventMachine.instance.add_server self
    end
    
    # set up an eventmachine periodic task for event reception
    def run
      EM::run {
        EventMachine::PeriodicTimer.new(1) do
	  events = @controller.fetch_events
	  next if !events
	  p events
	  events.each do |event|
	    if(event.class == ZWave::SceneActivationEvent) then
	      # Scene Activation
	      activate_item = @controllers[event.node][event.scene-1]
	      puts "Trying to activate item #{activate_item} for scene #{event.scene} on node #{event.node}"
	      if(!Scenes::launch(activate_item.to_sym)) then
	        # no scene by that name, must be a device on/off button instead
		puts "No scene found."
	      end
	    elsif(event.class == ZWave::NotificationEvent) then
	      # Security Notification
	      # FIXME: don't hardcode all this, and support multiple profiles for different PINs
	      case event.type
	        when :unlocked
		  Scenes::launch :Home
		when :locked
		  Scenes::launch :Away
	      end
	    end
	  end
	end
      }
    end
  end
end

NestControl::Handlers.register :lighting, 0, NestControl::NestZWave.new
