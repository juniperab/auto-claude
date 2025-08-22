module AutoClaude
  module Output
    module Helpers
      class ResultFormatter
        def initialize(config = FormatterConfig.new)
          @config = config
          @link_parser = LinkParser.new(config)
        end
        
        def format(output)
          output_str = output.to_s
          lines = output_str.lines || []
          line_count = lines.length
          output_length = output_str.length
          
          header = build_header(line_count, output_length, lines[0])
          
          if should_show_preview?(line_count, output_length, lines[0])
            format_with_preview(header, lines)
          else
            header
          end
        end
        
        private
        
        def build_header(line_count, output_length, first_line)
          emoji = FormatterConfig::MESSAGE_EMOJIS[:result]
          size_kb = (output_length / FormatterConfig::KB_SIZE.to_f).round(1)
          
          if line_count == 0 || output_length == 0
            "#{emoji} Result: (empty)"
          elsif line_count == 1 && output_length <= FormatterConfig::MAX_LINE_LENGTH && !is_links_line?(first_line)
            "#{emoji} Result: #{first_line.to_s.chomp}"
          else
            "#{emoji} Result: [#{line_count} lines, #{size_kb}KB]"
          end
        end
        
        def should_show_preview?(line_count, output_length, first_line)
          line_count > 1 || 
          (line_count == 1 && output_length > FormatterConfig::MAX_LINE_LENGTH) || 
          is_links_line?(first_line)
        end
        
        def is_links_line?(line)
          line && line.to_s.match(/^Links:\s*\[/)
        end
        
        def format_with_preview(header, lines)
          formatted = format_preview_lines(lines)
          result = [header] + formatted[:lines]
          result << "    ..." if formatted[:has_more]
          result.join("\n")
        end
        
        def format_preview_lines(lines)
          preview_lines = []
          has_more = false
          line_index = 0
          
          while line_index < lines.length
            line = lines[line_index]
            
            if line.to_s.match(/^Links:\s*\[/)
              handle_links_line(line, preview_lines, lines, line_index) do |more|
                has_more = more
              end
              break
            else
              if preview_lines.length < FormatterConfig::MAX_PREVIEW_LINES
                preview_lines << "  #{line.to_s.chomp}"
              else
                has_more = true
                break
              end
            end
            
            line_index += 1
          end
          
          { lines: preview_lines, has_more: has_more }
        end
        
        def handle_links_line(line, preview_lines, all_lines, line_index)
          formatted_links = @link_parser.parse_links_line(line.to_s)
          
          if preview_lines.empty? && formatted_links[:lines].length > 1
            # Special case: Links at start get 6 lines total (header + 5 links)
            header_and_links = formatted_links[:lines].take(6)
            preview_lines.concat(header_and_links)
            
            has_more = header_and_links.length < formatted_links[:lines].length || 
                      formatted_links[:has_more] || 
                      line_index < all_lines.length - 1
          else
            # Not at start, use normal limit
            remaining = FormatterConfig::MAX_PREVIEW_LINES - preview_lines.length
            if remaining > 0
              lines_to_add = formatted_links[:lines].take(remaining)
              preview_lines.concat(lines_to_add)
              
              has_more = lines_to_add.length < formatted_links[:lines].length || 
                        formatted_links[:has_more] || 
                        line_index < all_lines.length - 1
            else
              has_more = true
            end
          end
          
          yield has_more
        end
      end
    end
  end
end