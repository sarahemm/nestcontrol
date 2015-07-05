module NestControl
  class Lighting
    include Singleton
    
    def setup
      @log = Log4r::Logger['lighting']
      Handlers[:trigger].first.bind_trigger :manualcontrol, lambda { |key, args, values|
        if(key == "Sync") then
	  send_lighting_status_update
	else
          manual_control(key, values[0])
	end
      }
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

    def send_lighting_status_update
      # reset the interface to start with so we start in a known state
      Handlers[:lighting].first.reset
      # go through each device and get/report the status
      Handlers[:lighting].first.devices.each do |device_name, device|
        begin
	  # see if the device supports level first
	  level = device.level / 100.00
          puts "#{device_name} is at level #{level}"
          Handlers[:trigger].first.send_trigger :category => :ManualControl, :key => device_name, :values => [level]
	  next
	rescue NoMethodError
	end
        
	# device doesn't support level, try simple on/off
	begin
	  # see if the device supports level first, if not then try simple on/off
	  on_status = device.on?
	  on_value = on_status ? 1.0 : 0.0
          puts "#{device_name}: #{on_status ? "on" : "off"}"
          Handlers[:trigger].first.send_trigger :category => :ManualControl, :key => device_name, :values => [on_value]
	  next
	rescue NoMethodError
	end
      end
    end
  end
end

Lighting.instance.setup
