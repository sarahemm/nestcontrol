# TODO: deal with overlapping priorities (bump the later-registered ones down maybe?)
module NestControl
  class Handlers
    include Singleton
    
    # register a class as a handler for a given category
    def self.register(category, priority, instance)
      log = Log4r::Logger['nestcontrol']
      
      @handlers = Hash.new if !@handlers
      @handlers[category] = Array.new if !@handlers[category]
      if(@handlers[category][priority]) then
        log.warn "Not registering #{instance.class} as a priority #{priority} handler for category #{category} as #{@handlers[category][priority].class} is already registered at that priority"
        return
      end
      log.info "Registering #{instance.class} as a priority #{priority} handler for category #{category}"
      @handlers[category][priority] = instance
    end
    
    def self.[](category)
      @handlers[category]
    end
  end
end
