module NestControl
  class Lighting
    include Singleton
    
    def setup
      @log = Log4r::Logger['lighting']
      Handlers[:trigger].first.bind_trigger :manualcontrol, lambda {|key, args, values| manual_control(key, values[0]) }
    end

    def manual_control(device_name, value)
      device = Handlers[:lighting].first[device_name]
      if(device.class == ZWave::Switch) then
        if(value >= 0.5) then
	  @log.info "Turning ZWave switch #{device_name} on via OSC"
	  device.on = true
	else
	  @log.info "Turning ZWave switch #{device_name} off via OSC"
	  device.on = false
	end
      elsif(device.class == ZWave::Dimmer) then
	@log.info "Setting #{device_name} to level #{value*100} via OSC"
	device.level = value * 100
      else
        @log.error "Don't know how to control device of type #{device.class} via OSC."
      end
    end
  end
end

Lighting.instance.setup
