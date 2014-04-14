require 'forecast_io'

# TODO: cache responses for some time and auto-update after that time
module NestControl
  class NestForecastIO
    def initialize
      log = Log4r::Logger['weather']
      
      ForecastIO.api_key = NestConfig[:forecastio][:account][:api_key]
      self.update_forecast
    end
    
    def update_forecast
      @latest_forecast = ForecastIO.forecast            \
        NestConfig[:forecastio][:location][:latitude],  \
        NestConfig[:forecastio][:location][:longitude], \
        params: {:units => NestConfig[:forecastio][:units], :exclude => "daily,alerts,flags"}
    end
    
    def temperature
      @latest_forecast[:currently][:temperature]
    end
    
    def wind_speed
      @latest_forecast[:currently][:windSpeed]
    end
    
    def current_conditions
      @latest_forecast[:currently][:summary]
    end
    
    def short_term_forecast
      @latest_forecast[:minutely][:summary]
    end

    def medium_term_forecast
      @latest_forecast[:hourly][:summary]
    end
  end
end

NestControl::Handlers.register :weather, 0, NestControl::NestForecastIO.new