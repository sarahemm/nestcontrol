module NestControl
  class DoorLock
    include Singleton
      
    # TODO: don't hardcode a lot of things that are hardcoded in this module
    def setup
      @log = Log4r::Logger['lighting']
      Handlers[:trigger].first.bind_trigger :frontdoor, lambda { |key, args, values|
        next if values != [1.0]
	case key
	  when "Sync"
	    send_lock_update
	  when "CheckBattery"
	    send_battery_update
	  when "Lock"
            lock_door
	  when "Unlock"
	    unlock_door
	end
      }
    end

    def lock_door
      Handlers[:trigger].first.send_trigger :category => :FrontDoor, :key => :Wait, :values => ["Wait..."]
      device = Handlers[:lighting].first['front_door_lock']
      device.lock
      send_lock_update
    end
    
    def unlock_door
      Handlers[:trigger].first.send_trigger :category => :FrontDoor, :key => :Wait, :values => ["Wait..."]
      device = Handlers[:lighting].first['front_door_lock']
      device.unlock
      send_lock_update
    end

    def send_lock_update
      Handlers[:trigger].first.send_trigger :category => :FrontDoor, :key => :Wait, :values => ["Wait..."]
      Handlers[:trigger].first.send_trigger :category => :FrontDoor, :key => :Locked, :values => [0.0]
      Handlers[:trigger].first.send_trigger :category => :FrontDoor, :key => :Unlocked, :values => [0.0]
      device = Handlers[:lighting].first['front_door_lock']
      locked = device.locked?
      Handlers[:trigger].first.send_trigger :category => :FrontDoor, :key => :Locked, :values => [locked ? 1.0 : 0.0]
      Handlers[:trigger].first.send_trigger :category => :FrontDoor, :key => :Unlocked, :values => [locked ? 0.0 : 1.0]
      Handlers[:trigger].first.send_trigger :category => :FrontDoor, :key => :Wait, :values => [""]
    end
    
    def send_battery_update
      device = Handlers[:lighting].first['front_door_lock']
      battery_level = "#{device.battery_level}%"
      Handlers[:trigger].first.send_trigger :category => :FrontDoor, :key => :BatteryLevel, :values => [battery_level]
    end
  end
end

DoorLock.instance.setup
