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
          
          # Calculate indent for ellipsis to match the formatted lines
          if formatted[:has_more] && formatted[:lines].any?
            # Get the indent of the first formatted line
            first_line = formatted[:lines].first || ""
            indent = first_line[/\A */].length
            result << "#{' ' * indent}..."
          elsif formatted[:has_more]
            result << "        ..."  # Default 8 spaces if no lines
          end
          
          result.join("\n")
        end
        
        def format_preview_lines(lines)
          preview_lines = []
          has_more = false
          line_index = 0
          max_lines = @config.max_lines || FormatterConfig::MAX_PREVIEW_LINES
          
          # First pass: collect lines to display (up to max_lines)
          lines_to_display = []
          while line_index < lines.length && lines_to_display.length < max_lines
            line = lines[line_index]
            
            # Special handling for Links lines
            if line.to_s.match(/^Links:\s*\[/)
              handle_links_line(line, preview_lines, lines, line_index) do |more|
                has_more = more
              end
              return { lines: preview_lines, has_more: has_more }
            else
              lines_to_display << line.to_s
            end
            
            line_index += 1
          end
          
          has_more = line_index < lines.length
          
          # Calculate smart indentation
          padding = calculate_smart_indent(lines_to_display)
          
          # Apply indentation to all lines
          lines_to_display.each do |line|
            # Convert leading tabs to spaces and apply padding
            formatted_line = convert_leading_tabs(line)
            preview_lines << "#{padding}#{formatted_line.chomp}"
          end
          
          { lines: preview_lines, has_more: has_more }
        end
        
        private
        
        def calculate_smart_indent(lines, target_indent = FormatterConfig::STANDARD_INDENT)
          return " " * target_indent if lines.empty?
          
          # Find minimum indent among all lines (ignoring empty lines)
          min_indent = lines.map do |line|
            # Convert tabs to spaces for calculation
            expanded = convert_leading_tabs(line)
            # Skip empty or whitespace-only lines
            next nil if expanded.strip.empty?
            # Count leading spaces
            expanded.length - expanded.lstrip.length
          end.compact.min || 0
          
          # Calculate padding needed to reach target indent
          padding_needed = [target_indent - min_indent, 0].max
          " " * padding_needed
        end
        
        def convert_leading_tabs(line)
          # Convert leading tabs and spaces-followed-by-tabs to spaces
          # This handles mixed indentation properly
          result = ""
          converted_leading = false
          
          line.chars.each do |char|
            if !converted_leading && (char == "\t" || char == " ")
              if char == "\t"
                result += "    "  # Tab = 4 spaces
              else
                result += char  # Keep spaces as-is
              end
            else
              converted_leading = true
              result += char
            end
          end
          
          result
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