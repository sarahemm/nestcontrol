#!/opt/local/bin/ruby1.9

require 'rubygems'
require 'log4r'
require 'log4r/yamlconfigurator'
require './config.rb'
require './handlers.rb'

include NestControl
basedir = File.dirname(__FILE__)

# set up logging
Log4r::YamlConfigurator.decode_yaml(YAML.load_file("#{basedir}/etc/logging.yaml"))
@log = Log4r::Logger['nestcontrol']

# used by modules to depend on other modules/load them first
def depends_on(mod)
  @log.info "Loading module '#{mod}' as a dependency"
  loaded = require "#{File.dirname(__FILE__)}/modules/#{mod.to_s}.rb"
  @log.info "Module '#{mod}' already loaded, not re-loading" if !loaded
end

# load all the config files
NestConfig::load_files("#{basedir}/etc/*.yaml")

# load all the core support classes
Dir.glob("#{basedir}/lib/core*.rb").each do |file|
  @log.info "Loading core support library '#{File.basename(file, ".rb")}'"
  load file
end

# load all the other support classes
Dir.glob("#{basedir}/lib/*.rb").each do |file|
  next if File.basename(file).start_with? 'core' # we already loaded core classes, skip them now
  @log.info "Loading support library '#{File.basename(file, ".rb")}'"
  load file
end

# load all the modules
module_list = Dir.glob("#{basedir}/modules/*.rb").sort
module_list.each do |file|
  @log.info "Loading module '#{File.basename(file, ".rb")}'"
  loaded = require file
  @log.info "Module '#{File.basename(file, ".rb")}' already loaded, not re-loading" if !loaded
end

@log.info "Initialization complete, system ready"
CoreEventMachine.instance.run
