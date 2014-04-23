require 'osc-ruby'
require 'osc-ruby/em_server'

module NestControl
  class NestOSC
    #include Singleton

    def initialize
      @log = Log4r::Logger['network']

      # create an OSC server instance and add it to the list of EM servers to run
      @osc_server = OSC::EMServer.new(8000) # TODO: configurable
      
      @log.debug "Registering OSC backend with CoreEventMachine"
      CoreEventMachine.instance.add_server @osc_server
    end

    # attach a callback to one category of OSC messages
    def bind_trigger(category, callee)
      category_match = /\/#{category.to_s}\/(.*)/i
      @log.info "Binding OSC category '#{category}' to callee #{callee}"
      @osc_server.add_method category_match do |message|
        address = category_match.match(message.address)[1]
        args = message.to_a
        @log.debug "OSC message #{address}=#{args} received, calling #{callee}"
        callee.call address, args
      end
    end
  end
end

NestControl::Handlers.register :trigger, 0, NestControl::NestOSC.new
