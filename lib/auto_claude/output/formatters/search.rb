module AutoClaude
  module Output
    module Formatters
      class Search < Base
        def format(tool_name, input)
          case tool_name.downcase
          when "ls"
            format_ls(input)
          when "glob"
            format_glob(input)
          when "grep"
            format_grep(input)
          when "websearch"
            format_websearch(input)
          else
            "🔍 Search: #{tool_name}"
          end
        end
        
        private
        
        def format_ls(input)
          path = extract_value(input, "path") || "."
          ignore = extract_value(input, "ignore")
          indent = " " * FormatterConfig::STANDARD_INDENT
          filter = ignore ? "\n#{indent}filter: excluding #{ignore}" : ""
          
          "#{FormatterConfig::TOOL_EMOJIS[:ls]} Listing #{path}/#{filter}"
        end
        
        def format_glob(input)
          pattern = extract_value(input, "pattern") || "*"
          "#{FormatterConfig::TOOL_EMOJIS[:glob]} Searching for #{pattern}"
        end
        
        def format_grep(input)
          pattern = extract_value(input, "pattern") || ""
          path = extract_value(input, "path")
          context = extract_grep_context(input)
          indent = " " * FormatterConfig::STANDARD_INDENT
          
          location = path ? "\n#{indent}in: #{path}" : ""
          context_info = context ? "\n#{indent}context: ±#{context} lines" : ""
          
          "#{FormatterConfig::TOOL_EMOJIS[:grep]} Searching for '#{pattern}'#{location}#{context_info}"
        end
        
        def format_websearch(input)
          query = extract_value(input, "query") || ""
          "#{FormatterConfig::TOOL_EMOJIS[:websearch]} Web searching: '#{query}'"
        end
        
        def extract_grep_context(input)
          return nil unless input.is_a?(Hash)
          
          a = extract_value(input, "-A")
          b = extract_value(input, "-B")
          c = extract_value(input, "-C")
          
          c || (a && b && a == b ? a : nil)
        end
      end
    end
  end
end