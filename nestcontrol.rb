#!/opt/local/bin/ruby1.9

require 'rubygems'
require 'log4r'
require 'log4r/yamlconfigurator'
require './config.rb'
require './handlers.rb'

include NestControl
basedir = File.dirname(__FILE__)

# used by modules to depend on other modules/load them first
def depends_on(mod)
  puts "Loading #{mod} as a dependency"
  require "#{File.dirname(__FILE__)}/modules/#{mod.to_s}.rb"
end

# set up logging
Log4r::YamlConfigurator.decode_yaml(YAML.load_file("#{basedir}/etc/logging.yaml"))
log = Log4r::Logger['nestcontrol']

# load all the config files
NestConfig::load_files("#{basedir}/etc/*.yaml")

# load all the support classes
Dir.glob("#{basedir}/lib/*.rb").each do |file|
  log.info "Loading support library '#{File.basename(file, ".rb")}'"
  load file
end

# load all the modules
module_list = Dir.glob("#{basedir}/modules/*.rb").sort
module_list.each do |file|
  log.info "Loading module '#{File.basename(file, ".rb")}'"
  loaded = require file
  log.info "Module '#{File.basename(file, ".rb")}' already loaded, not re-loading" if !loaded
end

log.info "Initialization complete, system ready"
CoreEventMachine.instance.run
