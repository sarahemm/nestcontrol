# depends_on speech

# TODO: this module is getting unmanagably nested already, and there's still a lot to come
module NestControl
  class Scenes
    def self.launch(name)
      log = Log4r::Logger['scenes']
      
      scene = NestConfig[:scenes][name]
      if(!scene) then
        log.warn "Attempted to launch non-existent scene '#{name}'"
        return nil
      end
      scene.each do |category, category_data|
        case category
          # AUDIO
          when :audio
            self.process_audio category_data
          
          # LIGHTING
          when :lighting
            category_data.each do |device, on|
              if(on) then
                log.info "Turning on #{device}"
                Handlers[:lighting].first[device.to_s].switch_on
              else
                log.info "Turning off #{device}"
                Handlers[:lighting].first[device.to_s].switch_off
              end
            end
          
          # SPEECH HOOKS
          when :speech_hook
            Speech.instance.hooks(category_data[:name]).activate(category_data[:speaker])
          
          # UNKNOWN
          else
            log.warn "Found unknown category '#{category}' in scene, ignoring"
        end
      end
    end
  
    private
    
    def self.process_audio(config)
      log = Log4r::Logger['scenes']
      audio = Handlers[:audio].first
      
      config.each do |category, data|
        case category
          # transport controls (play/stop/etc.)
          when :transport
            data.each do |speaker, operation|
              case operation
                when "stop"
                  if(speaker == :all) then
                    audio.stop_all
                  else
                    audio.speaker(speaker.to_s).stop
                  end
              end
            end
          
          # group speakers together
          # TODO: currently this ungroups everything to start, this isn't very flexible
          when :group
            audio.ungroup_all
            master_speaker = data[0].to_s
            slave_speakers = data[1..-1]
            slave_speakers.each do |slave_speaker|
              audio.speaker(master_speaker.to_s).add_group_slave audio.speaker(slave_speaker.to_s)
            end
          
          # load content into a speaker/group
          when :content
            data.each do |speaker, content|
              content_url = NestConfig[:audio][:streams][content.to_sym]
              if(!content_url) then
                log.warn "Can't find stream for shortname '#{content}', not playing"
                break
              end
              audio.speaker(speaker.to_s).play_url content_url
            end
            
          else          
            log.warn "Found unknown audio category '#{category}' in scene, ignoring"
        end
      end
    end
  end
end
