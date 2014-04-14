require 'yaml'

module NestControl  
  class NestConfig
    include Singleton
    
    def self.load_files(filespec)
      log = Log4r::Logger['nestcontrol']
      
      @config = Hash.new if !@config
      Dir.glob(filespec).each do |file|
        log.info "Loading config file #{File.basename(file)}"
        @config[File.basename(file, ".yaml").to_sym] = self.symbolize(YAML.load_file(file))
      end
    end
    
    def self.[](key)
      @config[key]
    end
    
    private
    
    def self.symbolize(obj)
        return obj.inject({}){|memo,(k,v)| memo[k.to_sym] =  symbolize(v); memo} if obj.is_a? Hash
        return obj.inject([]){|memo,v    | memo           << symbolize(v); memo} if obj.is_a? Array
        return obj
    end
  end
end
