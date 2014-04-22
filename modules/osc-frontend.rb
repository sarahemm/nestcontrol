depends_on :scenes

module NestControl
  class OSCFrontend
    include Singleton
    
    def setup
      @log = Log4r::Logger['network']
      
      NestOSC.instance.register_with "/Scenes/.*", lambda {|args| launch_scene(args) }
      NestOSC.instance.register_with "/ManualControl/.*", lambda {|args| manual_control(args) }
    end

    def launch_scene(osc_params)
      return if osc_params.to_a[0] != 1.0
      scene_name = /^\/Scenes\/(.*)$/.match(osc_params.address)[1]
      @log.info "Launching scene #{scene_name} via OSC"
      Scenes::launch scene_name.to_sym
    end

    def manual_control(osc_params)
      device_name = /^\/ManualControl\/(.*)$/.match(osc_params.address)[1]
      value = osc_params.to_a[0]
      @log.info "Setting ZWave device #{device_name} to level #{value} via OSC"
      Handlers[:lighting].first[device_name].set(value)
    end
  end
end

OSCFrontend.instance.setup
