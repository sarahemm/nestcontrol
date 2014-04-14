module NestControl
  class Speech
    include Singleton

    def hooks(hook)
      @hooks = Hash.new if !@hooks
      @hooks[hook] = SpeechHook.new(hook)
    end
  end

  class SpeechHook
    def initialize(name)
      @name = name
      @log = Log4r::Logger['speech']
      @hook_callees = Hash.new
    end
    
    def register_with(priority, callee)
      @log.info "Registering #{callee} with speech hook #{@name}"
      @hook_callees["#{priority}#{callee}".to_sym] = callee
    end
    
    # TODO: maybe speaker should be a configured attribute of the hook itself, somewhere?
    def activate(speaker)
      @log.info "Activating speech hook #{@name} via speaker #{speaker}"
      phrase = ""
      # go through everything registered and either add the static text or call the procedure
      # to generate dynamic text
      @hook_callees.merge(NestConfig[:speech][:hook_speech][@name.to_sym]).each do |priority, item|
        if(item.class == String)
          phrase += item
        else
          puts "Calling '#{item}' to generate speech"
        end
      end
      @log.debug "Saying \"#{phrase}\" for activated hook #{@name}"
      
      # render the phrase to a sound file URL then play it
      Handlers[:audio].first.speaker(speaker).play_announcement_url(Handlers[:tts].first.render_speech(phrase))
    end
  end
end