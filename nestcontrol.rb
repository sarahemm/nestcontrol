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
# TODO: this should be put into a subroutine rather than inlined here
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
      depends_on_list = re[1]
      # found dependency info, check if we need to re-order this item
      highest_dep_index = -1
      depends_on_list.split(/,\s*/).each do |depends_on_module|
        depends_on = "#{module_dir}#{depends_on_module}.rb"
        depends_on_index = module_list.index(depends_on)
        raise RuntimeError, "Unable to find dependency #{depends_on} for module #{file}" if !depends_on_index
        highest_dep_index = depends_on_index if depends_on_index > highest_dep_index
      end
      next if index > highest_dep_index
      # we do need to re-order it, remove the item and add it before what it depends on
      module_list.delete_at index
      module_list.insert(highest_dep_index + 1, file)
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
CoreEventMachine.instance.run
