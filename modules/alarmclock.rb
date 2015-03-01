depends_on :scheduler
depends_on :speech

# TODO: deal with setting the next day's alarm even if we launch after the setting time
module NestControl
  class AlarmClock
    include Singleton

    # schedule our repeating daily event to set up the next day's alarm
    def setup
      @log = Log4r::Logger['scheduler']
      
      # schedule a daily repeating event to set the alarm at the configured time
      set_time = NestConfig[:alarm_clock][:schedule][:set_at]
      set_hour = set_time.to_s[0..1]
      set_minute = set_time.to_s[2..3]
      Scheduler.instance.schedule_repeating "alarmclock_set", "#{set_minute} #{set_hour} * * *", lambda { autoset_next_alarm }
      
      # hook up any configured speech hooks
      NestConfig[:alarm_clock][:speech_hooks].each do |name, cfg|
        case cfg[:type].to_sym
          when :time_until_alarm
            Speech.instance.hooks(name).register_with(cfg[:priority], :time_until_alarm, lambda { time_until_alarm })
          else
            @log.warn "Found unknown hook type '#{cfg[:type]}' in alarm clock configuration, ignoring"
        end
      end
      
      # hook up the child triggers to change the set alarm time
      Handlers[:trigger].first.bind_trigger :alarmclock, lambda {|key, args, values|
        break if values[0] != 1.0
        case key
          when 'Off'
            disable_next_alarm
          when 'Set'
            set_alarm_from_trigger args[0], args[1]
          when 'Sync'
            send_alarm_trigger
        end
      }
    end
    
    # set the next day's alarm to the pre-scheduled time
    def autoset_next_alarm
      # don't re-set the alarm if it's already been manually set
      if(get_alarm_time) then
        @log.debug "Not auto-setting alarm as it has already been manually set"
        return
      end
      # next alarm will be tomorrow at whatever time is set for that day of the week
      tomorrow = Time.now + 60*60*24
      next_day = tomorrow.strftime("%A").downcase.to_sym
      alarm_time = NestConfig[:alarm_clock][:schedule][:alarm][next_day]
      alarm_hour = alarm_time.to_s[0..1]
      alarm_minute = alarm_time.to_s[2..3]
      set_alarm_time alarm_hour, alarm_minute

      # announce what we set the alarm for
      announcement = "Since tomorrow is #{next_day}, I've set your alarm for #{alarm_hour}:#{alarm_minute}."
      Speech.instance.make_announcement announcement
    end
    
    def disable_next_alarm
      # TODO: deal with disabling before setting time
      @log.info "Disabling next alarm"
      Scheduler.instance.delete_by_tag("alarmclock")
      # update any UIs that care by sending a trigger with the updated data
      send_alarm_trigger
    end
    
    # set alarm to a specific time
    # this picks the next instance of the specified time
    # (i.e. if set for 0700 at 0600 sets for today, if set for 0700 at 0800 sets for tomorrow)
    def set_alarm_time(hour, minute)
      today = Time.now
      tomorrow = Time.now + 60*60*24
      alarm_today = Time.local(today.year, today.month, today.day, hour, minute)
      alarm_tomorrow = Time.local(tomorrow.year, tomorrow.month, tomorrow.day, hour, minute)
      
      if(alarm_today < Time.now) then
        # already passed the requested time today, set it for tomorrow
        time = alarm_tomorrow
        @log.info "Scheduling alarm for #{time.to_s} tomorrow"
      else
        # the requested time today hasn't passed yet, so set it for today
        time = alarm_today
        @log.info "Scheduling alarm for #{time.to_s} today"
      end
      NestConfig[:alarm_clock][:actions].each do |name, cfg|
        # only add this action if it's supposed to be included on this day
        next if cfg[:only_on] && !cfg[:only_on].include?(time.strftime("%A"))
	action_time = time + cfg[:offset] * 60
        @log.debug "Adding alarm action '#{name}' at #{action_time}"
        Scheduler.instance.schedule_oneshot "alarmclock_#{name}", action_time, lambda { Scenes::launch name.to_sym }, "alarmclock"
      end
    end
    
    # get the time of the next alarm
    def get_alarm_time
      # TODO: don't hardcode this tag
      alarm_jobs = Scheduler.instance.get_by_tag("alarmclock")
      return nil if !alarm_jobs[0]
      alarm_jobs[0].next_time
    end
    
    # set the alarm from an x,y button grid trigger
    def set_alarm_from_trigger(hour_val, minute_val)
      # decode what time the button the user pressed refers to
      # TODO: put this in config file
      hour_values = [5, 6, 7, 8, 9, 10]
      minute_values = [0, 15, 30, 45]
      hour = hour_values[hour_val.to_i - 1]
      minute = minute_values[minute_val.to_i - 1]
      # get rid of any existing alarm setup
      Scheduler.instance.delete_by_tag("alarmclock")
      # set the new alarm to the time requested
      set_alarm_time hour, minute
      # update any UIs that care by sending a trigger with the updated data
      send_alarm_trigger
    end
        
    # send a trigger out announcing what the alarm is currently set for
    def send_alarm_trigger
      alarm_time = get_alarm_time
      alarm_time_msg = "No alarm set"
      alarm_time_msg = "Alarm set for #{alarm_time.strftime("%H:%M")}" if alarm_time
      Handlers[:trigger].first.send_trigger :category => :AlarmClock, :key => :TimeSetFor, :values => [alarm_time_msg]
    end
    
    # return the time until the next alarm, for speech hook use
    def time_until_alarm
      alarm_time = get_alarm_time
      if(!alarm_time)
        # alarm isn't set yet, must be calling the hook before setting time. set it now.
        autoset_next_alarm
        alarm_time = get_alarm_time
      end
      alarm_text_time = alarm_time.strftime("%H:%M")
      time_until_secs = alarm_time - Time.now
      time_until_text = "#{(time_until_secs / (60*60)).floor} hours and #{(time_until_secs % (60*60) / 60).round} minutes"
      "I'll be waking you up at #{alarm_text_time}, which is #{time_until_text} from now."
    end
  end
end

AlarmClock.instance.setup
