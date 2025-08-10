require_relative 'writer'
require_relative 'formatter'
require 'json'

module AutoClaude
  module V2
    module Output
      class File < Writer
        def initialize(filename, append: false)
          @filename = filename
          @file = ::File.open(filename, append ? 'a' : 'w')
          @file.sync = true
          @formatter = Formatter.new(color: false, truncate: false)
        rescue => e
          raise ArgumentError, "Failed to open log file '#{filename}': #{e.message}"
        end

        def write_message(message)
          formatted = @formatter.format_message(message)
          @file.puts formatted
        end

        def write_user_message(text)
          formatted = @formatter.format_user_prompt(text)
          @file.puts formatted
        end

        def write_stat(key, value)
          @file.puts "  #{key}: #{value}"
        end

        def write_error(error)
          @file.puts "  Error: #{error}"
        end

        def write_info(info)
          @file.puts "  #{info}"
        end

        def write_divider
          @file.puts "---"
        end

        def write_metadata(metadata)
          @file.puts metadata.to_json
        end

        def close
          @file.close unless @file.closed?
        end
      end
    end
  end
end