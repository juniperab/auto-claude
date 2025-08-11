require_relative 'writer'
require_relative 'formatter'

module AutoClaude
    module Output
      class Terminal < Writer
        COLORS = {
          blue: "\e[94m",
          cyan: "\e[96m",
          light_gray: "\e[37m",
          dark_gray: "\e[90m",
          red: "\e[31m",
          white: "\e[97m",
          reset: "\e[0m"
        }.freeze

        def initialize(stream: $stderr, color: true, truncate: true, max_lines: 5)
          @stream = stream
          @color = color
          @truncate = truncate
          @max_lines = max_lines
          @formatter = Formatter.new(color: color, truncate: truncate, max_lines: max_lines)
        end

        def write_message(message)
          formatted = @formatter.format_message(message)
          # Skip filtered messages (nil return from formatter)
          return if formatted.nil?
          write_output(formatted, :white)
        end

        def write_user_message(text)
          formatted = @formatter.format_user_prompt(text)
          write_output(formatted, :blue)
        end

        def write_stat(key, value)
          formatted = "  #{key}: #{value}"
          write_output(formatted, :dark_gray)
        end

        def write_error(error)
          formatted = "  Error: #{error}"
          write_output(formatted, :red)
        end

        def write_info(info)
          formatted = "  #{info}"
          write_output(formatted, :dark_gray)
        end

        def write_divider
          write_output("---", :cyan)
        end

        private

        def write_output(text, color_name)
          # Add two-space indent to each line
          indented_text = text.lines.map { |line| "  #{line}" }.join
          
          if @color
            color = COLORS[color_name] || COLORS[:white]
            @stream.puts "#{color}#{indented_text}#{COLORS[:reset]}"
          else
            @stream.puts indented_text
          end
        end
      end
  end
end