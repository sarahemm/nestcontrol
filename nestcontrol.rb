#!/opt/local/bin/ruby1.9

require 'rubygems'
#require 'rufus/scheduler'
require 'ruby-osc'
require 'zwave'
require 'log4r'
require 'log4r/yamlconfigurator'
require './config.rb'
require './handlers.rb'

include NestControl

basedir = File.dirname(__FILE__)

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

# load all the actual modules
Dir.glob("#{basedir}/modules/*.rb").each do |file|
  log.info "Loading module '#{File.basename(file, ".rb")}'"
  load file
end

log.info "Initialization complete, system ready"

# TODO: figure out how to modularize this better
OSC.run do
  osc = OSC::Server.new 8000, "0.0.0.0"
  
  osc.add_pattern /^\/ManualControl\/(.*)$/ do |key, value|
    device_name = /^\/ManualControl\/(.*)$/.match(key)[1]
    log.info "Setting ZWave device #{device_name} to level #{value}"
    Handlers[:lighting].first[device_name].set(value)
  end
  
  osc.add_pattern /^\/Scenes\/(.*)$/ do |key, value|
    next if value < 1.0 # ignore "key up"
    scene_name = /^\/Scenes\/(.*)$/.match(key)[1]
    log.info "Launching scene #{scene_name}"
    Scenes::launch scene_name.to_sym
  end
end

#schedule = Rufus::Scheduler.new
#
#schedule.cron "*/1 * * * * *" do 
#  puts "1 second tick"
#end

# join the scheduling thread to the main one so we never exit
#schedule.join