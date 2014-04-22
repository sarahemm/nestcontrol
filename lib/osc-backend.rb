require 'osc-ruby'
require 'osc-ruby/em_server'

module NestControl
  class NestOSC
    include Singleton

    def setup
      @log = Log4r::Logger['network']

      # create an OSC server instance and add it to the list of EM servers to run
      @osc_server = OSC::EMServer.new(8000) # TODO: configurable
      
      #@@osc_server.add_method '/ManualControl/.*' do |message|
      #  puts "#{message.ip_address}:#{message.ip_port} -- #{message.address} -- #{message.to_a}"
      #end
      
      @log.debug "Registering OSC backend with CoreEventMachine"
      CoreEventMachine.instance.add_server @osc_server
    end

    def register_with(event_mask, callee)
      @osc_server.add_method event_mask do |message|
        @log.debug "OSC message #{message.address} = #{message.to_a.join} received, calling #{callee}"
        callee.call message
      end
    end
  end
end

NestControl::NestOSC.instance.setup
