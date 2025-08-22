module AutoClaude
  module Output
    module Formatters
      class Web < Base
        def format(tool_name, input)
          case tool_name.downcase
          when "webfetch"
            format_webfetch(input)
          when "websearch"
            format_websearch(input)
          else
            "🌐 Web: #{tool_name}"
          end
        end
        
        private
        
        def format_webfetch(input)
          url = extract_value(input, "url") || ""
          prompt = extract_value(input, "prompt")
          
          domain = extract_domain(url)
          analyzing = prompt && prompt.length > 0 ? 
            "\n  analyzing: #{prompt[0..50]}..." : ""
          
          "#{FormatterConfig::TOOL_EMOJIS[:webfetch]} Fetching #{domain}#{analyzing}"
        end
        
        def format_websearch(input)
          query = extract_value(input, "query") || ""
          "#{FormatterConfig::TOOL_EMOJIS[:websearch]} Web searching: '#{query}'"
        end
        
        def extract_domain(url)
          return "unknown" if url.nil? || url.empty?
          
          if url.match(%r{^https?://([^/]+)})
            domain = $1
            domain.sub(/^www\./, '')
          elsif url.include?('/')
            url.split('/')[2] || url
          else
            url
          end
        end
      end
    end
  end
end