require 'sonos'

module NestControl
  class NestSonos
    def initialize
      @log = Log4r::Logger['sonos']
      @log.info "Connecting to Sonos system controller"
      @disco = Sonos::Discovery.new
      @sonos = Sonos::System.new @disco.topology
    end
    
    def speaker(speaker_name)
      # look through all the speakers to find one that matches
      @sonos.speakers.each do |speaker|
        if(speaker.name == speaker_name)
          return Speaker.new @sonos, @disco, speaker
        end
      end
      
      # couldn't find it!
      nil
    end
    
    def stop_all
      # FIXME: we can't use ruby-sonos' pause_all, beacuse if something is already
      # paused it errors out with a UPnPError.
      # We should fix this in ruby-sonos and send the fix upstream.
      #@sonos.pause_all
      @sonos.speakers.each do |speaker|
        speaker.pause if speaker.get_player_state[:state] == "PLAYING"
      end
      
      @log.info "Stopping audio everywhere"
    end
    
    def ungroup_all
      @log.info "Ungrouping all speakers"
      @sonos.party_over
      @sonos.rescan @disco.topology
    end
    
    class Speaker
      def initialize(system, disco, speaker)
        @log = Log4r::Logger['sonos']
        @system = system
        @disco = disco
        @speaker = speaker
      end
      
      def name
        @speaker.name
      end
      
      def speaker_object
        @speaker
      end
      
      # fade out then stop whatever was playing, then reset volume to where we started
      def fade_out
        old_volume = @speaker.volume
        while(@speaker.volume > 10) do
          new_volume = @speaker.volume -= 10
          new_volume = 0 if new_volume < 0
          @speaker.volume = new_volume
          sleep 0.1
        end
        @speaker.stop
        @speaker.volume = old_volume
      end
      
      # fade the volume up to a given level
      def fade_in(desired_volume)
        while(@speaker.volume < desired_volume) do
          new_volume = @speaker.volume += 10
          new_volume = desired_volume if new_volume > desired_volume
          @speaker.volume = new_volume
          sleep 0.1
        end
      end

      def play_url(url)
        @log.info "Playing URL #{url} on speaker #{@speaker.name}"
        @speaker.play url
        @speaker.play
      end
      
      def play
        @log.info "Playing audio on speaker #{@speaker.name}"
        @speaker.play
      end
      
      def pause
        @log.info "Pausing audio on speaker #{@speaker.name}"
        @speaker.pause if @speaker.get_player_state[:state] == "PLAYING"
      end
      
      def stop
        @log.info "Stopping audio on speaker #{@speaker.name}"
        @speaker.stop
      end
      
      def add_group_slave(slave_speaker)
        @log.info "Adding slave speaker #{slave_speaker.name} to master speaker #{@speaker.name}"
        begin
          @speaker.group(slave_speaker.speaker_object)
        rescue
          # FIXME: this is horrible and will hang forever if anything really goes wrong
          # sometimes we get UPnP 402 and have to try again though
          @log.error "Failed to join speaker, waiting 1 second and trying again"
        end
        # have to rescan for groups every time a node leaves/joins a group
        @system.rescan @disco.topology
      end
      
      # play an announcement, then go back to whatever was playing before
      # TODO: overlapping announcements will probably confuse everything
      def play_announcement_url(url)
        return if !url  # only try to play if we actually got something
        @log.info "Playing #{url} on speaker #{@speaker}"

        # keep track of then fade out what was playing before, if anything
        if @speaker.get_player_state[:state] == "PLAYING"
          was_playing = @speaker.now_playing[:uri]
          self.fade_out
        end

        # queue up and play the announcement
        @speaker.play(url)
        @speaker.play

        # wait until the announcement is all played
        # TODO: long announcements block everything else, right now, should fix this somehow
        sleep 0.25
        while(@speaker.get_player_state[:state] != "STOPPED") do
          sleep 0.25
        end

        # if anything was playing before, start it again
        if(was_playing) then
          old_volume = @speaker.volume
          @speaker.volume = 0
          @speaker.play was_playing
          @speaker.play
          
          # wait until it starts playing before fading back in
          while(@speaker.get_player_state[:state] != "PLAYING") do
            sleep 0.25
          end
          
          fade_in old_volume
        end
      end
    end
  end
end

NestControl::Handlers.register :audio, 0, NestControl::NestSonos.new
