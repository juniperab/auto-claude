module AutoClaude
  module Output
    module Formatters
      class Bash < Base
        def format(input)
          command = extract_value(input, "command")
          desc = extract_value(input, "description")
          
          emoji = FormatterConfig::TOOL_EMOJIS[:bash]
          
          if desc && command && command.length > FormatterConfig::LONG_COMMAND_THRESHOLD
            "#{emoji} Executing: #{desc}"
          else
            "#{emoji} Running: #{command || 'unknown'}"
          end
        end
      end
    end
  end
end