require 'hipe-core/interfacey'

module Hipe
  class Didcap
    include Hipe::Interfacey::Service
    interface.might do
      speaks :cli
      describe <<-desc
        didcap - capture screen at certain intervals, omitting duplicates
      desc

      default_request "help"

      responds_to("start") do
        describe "start recording with the specified settings"
        opts.on('-h','--help','this screen',&help)
      end

      responds_to("stop") do 
        describe "stop recording"
        opts.on('-h','--help','this screen',&help)        
      end

      responds_to "help", "this page", :aliases=>['-h','--help','-?']
    end
    
    
  end
end