module AutoClaude
  module Output
    module Helpers
      class TextTruncator
        def initialize(config = FormatterConfig.new)
          @config = config
          @truncate = config.truncate
          @max_lines = config.max_lines
        end
        
        def truncate(text, special_case: false)
          return "" if text.nil?
          return text if special_case || !@truncate
          
          text_str = text.to_s
          lines = text_str.lines || []
          
          if lines.length > @max_lines
            truncate_multiline(lines)
          elsif text_str.length > FormatterConfig::MAX_LINE_LENGTH && lines.length == 1
            truncate_single_line(text_str)
          else
            text_str.chomp
          end
        end
        
        private
        
        def truncate_multiline(lines)
          truncated = lines.take(@max_lines).join.chomp
          truncated_count = lines.length - @max_lines
          "#{truncated}\n  (+ #{truncated_count} more lines...)"
        end
        
        def truncate_single_line(text)
          "#{text[0..FormatterConfig::MAX_LINE_LENGTH]}..."
        end
      end
    end
  end
end