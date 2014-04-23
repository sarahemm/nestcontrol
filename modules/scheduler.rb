require 'rufus/scheduler'

module NestControl
  class Scheduler
    include Singleton
    
    # schedule everything in the config
    def self.schedule_items
      log = Log4r::Logger['scheduler']
      
      day_to_cron = {
        :sun => 0, 
        :mon => 1,
        :tue => 2,
        :wed => 3,
        :thu => 4,
        :fri => 5,
        :sat => 6 
      }
      
      @@schedule = Rufus::Scheduler.new
      NestConfig[:schedule].each do |name, cfg|
        if(cfg[:time]) then
          # it's a "run at X time" item
          hour = cfg[:time].to_s[0..1]
          minute = cfg[:time].to_s[2..3]
          # assume the job will run every day until we find out otherwise
          days_cron = "*"
          days_text = "every day"
          # build a cron string and a text string to show what days to run this job
          if(cfg[:days]) then
            days_cron = cfg[:days].map {|day_text| day_to_cron[day_text.downcase[0..2].to_sym] }.join(",")
            days_text = "on " + cfg[:days].map {|day_text| day_text[0..2] }.join(", ")
          end
          cron_string = "#{minute} #{hour} * * #{days_cron}"
          log.info "Scheduling #{name} to run at #{hour}#{minute} #{days_text}"
          # actually schedule the item to run at the given time
          @@schedule.cron cron_string do
            log.info "Launching scheduled task #{name}"
            Scenes::launch cfg[:scene].to_sym
          end
        elsif(cfg[:every]) then
          # it's a "run every X amount of time" item
          log.warn "'every' type schedule items not yet supported, ignoring"
        else
          log.warn "Can't figure out what type of schedule #{name} should run on, ignoring"
        end
      end
    end
    
    # schedule an event on-demand that will repeat
    def schedule_repeating(name, cron_string, task, tag = nil)
      log = Log4r::Logger['scheduler']
      log.debug "Adding repeating scheduled task '#{name}' with schedule '#{cron_string}'"
      @@schedule.cron cron_string, :tag => tag do
        log.info "Launching repeating task #{name}"
        task.call
      end
    end
    
    # schedule an event on-demand that only runs once
    def schedule_oneshot(name, at_string, task, tag = nil)
      log = Log4r::Logger['scheduler']
      log.debug "Adding oneshot scheduled task '#{name}' to run at #{at_string}"
      @@schedule.at at_string, :tag => tag do
        log.info "Launching oneshot task #{name}"
        task.call
      end
    end
    
    # get a list of the scheduled events matching a specific tag
    def get_by_tag(tag)
      @@schedule.jobs :tag => tag
    end
    
    # delete all the jobs matching a specific tag
    def delete_by_tag(tag)
      log = Log4r::Logger['scheduler']
      @@schedule.jobs(:tag => tag).each do |job|
        log.debug "Unscheduling job #{job} matching tag #{tag}"
        job.unschedule
      end
    end
  end
end

Scheduler::schedule_items
