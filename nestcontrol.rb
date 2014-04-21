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

# reorder the list of modules by looking at their dependency information
module_dir = "#{basedir}/modules/"
module_list = Dir.glob("#{module_dir}*.rb").sort
pass = 0
while(true) do
  log.debug "Starting module dependency resolution, pass #{pass}"
  changes_made = false
  module_list.each_index do |index|
    file = module_list[index]
    File.open(file, "r") do |handle|
      # check if the file has dependency info in the first line
      first_line = handle.readline
      next if !re = first_line.match(/^#\s*depends_on\s+(.*)/)
      depends_on = "#{module_dir}#{re[1]}.rb"
      # found dependency info, check if we need to re-order this item
      depends_on_index = module_list.index depends_on
      next if index > depends_on_index
      # we do need to re-order it, remove the item and add it before what it depends on
      module_list.delete_at index
      module_list.insert(depends_on_index + 1, file)
      changes_made = true
    end
  end
  break if !changes_made
  pass += 1
  raise RuntimeError, "Unable to resolve all module dependencies after #{pass} attempts." if pass == 5
end

# load all the modules in the order they depend on each other in
module_list.each do |file|
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
