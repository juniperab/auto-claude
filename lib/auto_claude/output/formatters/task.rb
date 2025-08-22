module AutoClaude
  module Output
    module Formatters
      class Task < Base
        def format(input)
          desc = extract_value(input, "description") || "task"
          agent = extract_value(input, "subagent_type") || "general"
          
          "#{FormatterConfig::TOOL_EMOJIS[:task]} Delegating: #{desc}\n  agent: #{agent}"
        end
      end
    end
  end
end