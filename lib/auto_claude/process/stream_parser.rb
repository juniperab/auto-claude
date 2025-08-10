require 'json'
require_relative '../messages/base'

module AutoClaude
    module Process
      class StreamParser
        def initialize(handler)
          @handler = handler
          @buffer = ""
        end

        def parse(stream)
          stream.each_line do |line|
            line = line.strip
            next if line.empty?
            
            begin
              json = JSON.parse(line)
              
              # Skip system messages
              next if json["type"] == "system"
              
              # Parse into message object
              message = Messages::Base.from_json(json)
              
              # Call handler with the message
              @handler.call(message) if message
              
            rescue JSON::ParserError => e
              # Ignore malformed JSON lines
              # Could log this for debugging if needed
            end
          end
        end
      end
  end
end