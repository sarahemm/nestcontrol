module NestControl
  class WeatherReport
    def self.register_hooks
      log = Log4r::Logger['weather']
      speech = Speech.instance
      
      # go through each hook and register it with the speech hook manager
      NestConfig[:weather_report][:hooks].each do |name, cfg|
        speech.hooks(name).register_with(cfg[:priority], :weather_report, lambda { self.generate_report(cfg[:type]) })
      end
    end
    
    def self.generate_report(type)
      Handlers[:weather].first.update_forecast
      log = Log4r::Logger['weather']
      log.info "Generating '#{type}' type weather report"
      output = []
      NestConfig[:weather_report][:types][type.to_sym].each do |item|
        case item
          when "current_conditions"
            conditions = Handlers[:weather].first.current_conditions.chomp(".").downcase
            output.push "It's currently #{conditions} out"
          when "short_term"
            # if short term is the same as now and we're reporting both, simplify it
            short_term = Handlers[:weather].first.short_term_forecast.chomp(".").downcase
            if(NestConfig[:weather_report][:types][type.to_sym].include? "current_conditions") then
              if(short_term.sub(" for the hour", "") == Handlers[:weather].first.current_conditions.chomp(".").downcase) then
                output.push "continuing for the hour"
              else
                output.push "it will be #{short_term}"
              end
            else
              output.push "it will be #{short_term}"
            end
          when "medium_term"
            medium_term = Handlers[:weather].first.medium_term_forecast.chomp(".").downcase
            output.push "later it will be #{medium_term}"
          else
            log.warn "Unknown item #{item } in weather report type #{type}, ignoring"
        end
      end
      output.join(", ").capitalize + "."
    end
  end
end

WeatherReport::register_hooks
