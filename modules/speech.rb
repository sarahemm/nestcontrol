module NestControl
  class Speech
    include Singleton

    def hooks(hook)
      hook = hook.to_sym
      
      @hooks = Hash.new if !@hooks
      @hooks[hook] = SpeechHook.new(hook) if !@hooks[hook]
      @hooks[hook]
    end
    
    # TODO: remove hardcoded speaker (should announce everywhere)
    def make_announcement(text, speaker = "Bedroom")
      Handlers[:audio].first.speaker(speaker).play_announcement_url(Handlers[:tts].first.render_speech(text))
    end
  end

  class SpeechHook
    def initialize(name)
      @name = name
      @log = Log4r::Logger['speech']
      @hook_callees = Hash.new
      @log.debug "Initializing new speech hook '#{name}'"
    end
    
    def register_with(priority, name, callee)
      @log.info "Registering #{name} (#{callee}) with speech hook #{@name}"
      @hook_callees["#{priority}#{name}".to_sym] = callee
    end
    
    # TODO: maybe speaker should be a configured attribute of the hook itself, somewhere?
    def activate(speaker)
      @log.info "Activating speech hook #{@name} via speaker #{speaker}"
      phrase = ""
      # go through everything registered and either add the static text or call the procedure
      # to generate dynamic text
      @hook_callees.merge(NestConfig[:speech][:hook_speech][@name.to_sym]).sort.map do |priority, item|
        if(item.class == String)
          phrase += "#{item} "
        else
          @log.info "Calling '#{item}' to generate speech"
          phrase += "#{item.call} "
        end
      end
      @log.debug "Saying \"#{phrase}\" for activated hook #{@name}"
      
      # render the phrase to a sound file URL then play it
      Handlers[:audio].first.speaker(speaker).play_announcement_url(Handlers[:tts].first.render_speech(phrase))
    end
  end
end