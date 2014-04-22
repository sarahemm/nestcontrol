depends_on :scheduler
depends_on :speech

# TODO: deal with setting the next day's alarm even if we launch after the setting time
# TODO: add ability to adjust alarm clock both before or after it's set for the next day
# TODO: deal with going to sleep (and thus launching the hook) before the alarm setting time
module NestControl
  class AlarmClock
    # schedule our repeating daily event to set up the next day's alarm
    def self.setup
      log = Log4r::Logger['scheduler']
      set_time = NestConfig[:alarm_clock][:schedule][:set_at]
      set_hour = set_time.to_s[0..1]
      set_minute = set_time.to_s[2..3]
      Scheduler.instance.schedule_repeating "alarmclock_set", "#{set_minute} #{set_hour} * * *", lambda { self.set_next_alarm }

      NestConfig[:alarm_clock][:speech_hooks].each do |name, cfg|
        case cfg[:type].to_sym
          when :time_until_alarm
            Speech.instance.hooks(name).register_with(cfg[:priority], :time_until_alarm, lambda { self.time_until_alarm })
          else
            log.warn "Found unknown hook type '#{cfg[:type]}' in alarm clock configuration, ignoring"
        end
      end
    end
    
    # set the next day's alarm
    def self.set_next_alarm
      log = Log4r::Logger['scheduler']
      
      # next alarm will be tomorrow at whatever time is set for that day of the week
      tomorrow = Time.now + 60*60*24
      next_day = tomorrow.strftime("%A").downcase.to_sym
      next_alarm_time = NestConfig[:alarm_clock][:schedule][:alarm][next_day]
      next_alarm_hour = next_alarm_time.to_s[0..1]
      next_alarm_minute = next_alarm_time.to_s[2..3]
      next_alarm = Time.local(tomorrow.year, tomorrow.month, tomorrow.day, next_alarm_hour, next_alarm_minute)
      log.info "Scheduling next day's alarm for #{next_alarm.to_s}"
      NestConfig[:alarm_clock][:actions].each do |name, cfg|
        action_time = next_alarm + cfg[:offset] * 60
        log.debug "Adding alarm action '#{name}' at #{action_time}"
        Scheduler.instance.schedule_oneshot "alarmclock_#{name}", action_time, lambda { Scenes::launch name.to_sym }, "alarmclock"
      end
      announcement = "Since tomorrow is #{next_day}, I've set your alarm for #{next_alarm_hour}:#{next_alarm_minute}."
      # TODO: remove hardcoded speaker (should announce everywhere)
      Handlers[:audio].first.speaker("Bedroom").play_announcement_url(Handlers[:tts].first.render_speech(announcement))
    end
    
    # return the time until the next alarm, for speech hook use
    def self.time_until_alarm
      # TODO: don't hardcode this tag
      alarm_time = Scheduler.instance.get_by_tag("alarmclock")[0].next_time
      alarm_text_time = alarm_time.strftime("%H:%M")
      time_until_secs = alarm_time - Time.now
      time_until_text = "#{(time_until_secs / (60*60)).floor} hours and #{(time_until_secs % (60*60) / 60).round} minutes"
      "I'll be waking you up at #{alarm_text_time}, which is #{time_until_text} from now."
    end
  end
end

AlarmClock::setup
