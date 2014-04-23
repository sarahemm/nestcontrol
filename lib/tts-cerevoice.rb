require 'net/http'
require 'xmlsimple'

module NestControl
  class CereVoice
    REST_API_URL = "https://cerevoice.com/rest/rest_1_1.php"
    
    def initialize
    end
    
    # use CereVoice Cloud to render text into speech and return a URL to the sound file
    def render_speech(text, voice = NestConfig[:cerevoice][:defaults][:voice])
      log = Log4r::Logger['speech']
      log.info "Rendering #{text.length} characters of text in voice #{voice}"

      # build the XML REST request
      request = {
        "accountID"   => [NestConfig[:cerevoice][:account][:id]],
        "password"    => [NestConfig[:cerevoice][:account][:password]],
        "audioFormat" => ["mp3"],
        "voice"       => [voice],
        "text"        => [text]
      }
      request_xml = XmlSimple.xml_out(request, {"rootName" => "speakExtended"})
      
      # send the request as a POST to CereVoice
      uri = URI(REST_API_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http_response = http.post(uri.path, request_xml, {"Content-type" => "text/xml"})
      
      # parse out the resulting URL and return it
      response = XmlSimple.xml_in(http_response.body)
      if(response["resultCode"] != 1) then
        log.error "Failed to generate speech, error code was #{response["resultCode"][0]} (#{response["resultDescription"][0]})"
        return nil
      end
      response["fileUrl"][0]
    end
  end
end

NestControl::Handlers.register :tts, 0, NestControl::CereVoice.new
