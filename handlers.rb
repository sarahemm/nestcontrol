module NestControl
  class Handlers
    include Singleton
    
    # register a class as a handler for a given category
    def self.register(category, instance)
      log = Log4r::Logger['nestcontrol']
      
      log.info "Registering #{instance.class} as a handler for category #{category}"
      @handlers = Hash.new if !@handlers
      @handlers[category] = Array.new if !@handlers[category]
      @handlers[category].push instance
    end
    
    def self.[](category)
      @handlers[category]
    end
  end
end
