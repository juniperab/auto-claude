# frozen_string_literal: true

require_relative "writer"
require_relative "formatter"
require "json"

module AutoClaude
  module Output
    class File < Writer
      def initialize(filename, append: false)
        @filename = filename
        @file = ::File.open(filename, append ? "a" : "w")
        @file.sync = true
        @formatter = Formatter.new(color: false, truncate: false)
      rescue StandardError => e
        raise ArgumentError, "Failed to open log file '#{filename}': #{e.message}"
      end

      def write_message(message)
        formatted = @formatter.format_message(message)
        # Skip filtered messages (nil return from formatter)
        return if formatted.nil?

        write_indented(formatted)
      end

      def write_user_message(text)
        formatted = @formatter.format_user_prompt(text)
        write_indented(formatted)
      end

      def write_stat(key, value)
        write_indented("  #{key}: #{value}")
      end

      def write_error(error)
        write_indented("  Error: #{error}")
      end

      def write_info(info)
        write_indented("  #{info}")
      end

      def write_divider
        write_indented("---")
      end

      def close
        @file.close unless @file.closed?
      end

      private

      def write_indented(text)
        # Add two-space indent to each line
        indented_text = text.lines.map { |line| "  #{line}" }.join
        @file.puts indented_text
      end
    end
  end
end
