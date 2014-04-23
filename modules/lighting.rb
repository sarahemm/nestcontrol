module NestControl
  class Lighting
    include Singleton
    
    def setup
      @log = Log4r::Logger['lighting']
      Handlers[:trigger].first.bind_trigger :manualcontrol, lambda {|key, args| manual_control(key, args[0]) }
    end

    def manual_control(device_name, value)
      @log.info "Setting ZWave device #{device_name} to level #{value} via OSC"
      Handlers[:lighting].first[device_name].set(value)
    end
  end
end

Lighting.instance.setup
