module NestControl
  class CoreEventMachine
    include Singleton
    
    # add a server to the array of servers that we'll run once everything is set up
    def add_server(server)
      @servers = Array.new if !@servers
      @servers.push server
    end
    
    # start the eventmachine reactor and set up any servers that have been added
    def run
      log = Log4r::Logger['nestcontrol']
      
      EM.run do
        EM.error_handler { |e| log.error e }
        EM.set_quantum 5  # timer granularity at 5ms
        
        @servers.each do |server|
          log.debug "Launching EventMachine server '#{server}'"
          server.run
        end
      end
    end
  end
end