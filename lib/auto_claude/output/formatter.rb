# frozen_string_literal: true

require_relative "formatter_config"
require_relative "formatter_registry"
require_relative "formatters/base"
require_relative "formatters/bash"
require_relative "formatters/file"
require_relative "formatters/search"
require_relative "formatters/web"
require_relative "formatters/task"
require_relative "formatters/todo"
require_relative "formatters/mcp"
require_relative "helpers/text_truncator"
require_relative "helpers/link_parser"
require_relative "helpers/result_formatter"

module AutoClaude
  module Output
    class Formatter
      def initialize(color: true, truncate: true, max_lines: 5)
        @config = FormatterConfig.new(color: color, truncate: truncate, max_lines: max_lines)
        @registry = FormatterRegistry.new(@config)
        @text_truncator = Helpers::TextTruncator.new(@config)
        @result_formatter = Helpers::ResultFormatter.new(@config)
      end

      def format_message(message)
        # Show raw JSON for debugging when AUTOCLAUDE_SHOW_RAW_MESSAGES is set
        if ENV["AUTOCLAUDE_SHOW_RAW_MESSAGES"]
          max_length = ENV["AUTOCLAUDE_SHOW_RAW_MESSAGES"].to_i
          max_length = 160 if max_length <= 0 # Default to 160 if invalid

          raw = begin
            message.raw_json.to_json
          rescue StandardError
            message.inspect
          end
          truncated = raw.length > max_length ? "#{raw[0..(max_length - 4)]}..." : raw
          warn "[RAW] #{truncated}"
        end

        case message
        when Messages::TextMessage
          format_text_message(message)
        when Messages::ToolUseMessage
          format_tool_use(message)
        when Messages::ToolResultMessage
          format_tool_result(message)
        else
          "  [#{message.type}]"
        end
      rescue StandardError => e
        handle_formatting_error(e, message)
      end

      def format_user_prompt(text)
        "#{FormatterConfig::MESSAGE_EMOJIS[:user]} User: #{@text_truncator.truncate(text)}"
      end

      def format_session_start(directory)
        "#{FormatterConfig::MESSAGE_EMOJIS[:session_start]} Session: starting in #{directory}"
      end

      def format_session_complete(tasks, duration, cost)
        cost_str = format("%.6f", cost)
        "#{FormatterConfig::MESSAGE_EMOJIS[:session_complete]} Complete: #{tasks} tasks, #{duration}s, $#{cost_str}"
      end

      def format_stats(tokens_up, tokens_down)
        "#{FormatterConfig::MESSAGE_EMOJIS[:stats]} Stats: #{tokens_up}↑ #{tokens_down}↓ tokens"
      end

      private

      def format_text_message(message)
        text = message.text || ""
        special_case = text.include?("TodoWrite")
        "#{FormatterConfig::MESSAGE_EMOJIS[:assistant]} #{@text_truncator.truncate(text, special_case: special_case)}"
      end

      def format_tool_use(message)
        @registry.format_tool(message.tool_name, message.tool_input || {})
      end

      def format_tool_result(message)
        output = message.output || ""

        # Filter out certain messages unless AUTOCLAUDE_DISABLE_FILTERS is set
        if !message.is_error && should_filter_message?(output)
          return "[FILTERED] #{@result_formatter.format(output)}" if ENV["AUTOCLAUDE_DISABLE_FILTERS"]

          return nil

        end

        if message.is_error
          "#{FormatterConfig::MESSAGE_EMOJIS[:error]} Error: #{@text_truncator.truncate(output)}"
        else
          @result_formatter.format(output)
        end
      end

      def should_filter_message?(text)
        return false if text.nil? || text.empty?

        FormatterConfig::FILTERED_MESSAGE_PREFIXES.any? do |prefix|
          text.strip.start_with?(prefix)
        end
      end

      def handle_formatting_error(error, message)
        msg = "#{FormatterConfig::MESSAGE_EMOJIS[:error]} Warning: Failed to format message"
        warn "#{msg} - #{error.class}: #{error.message}"
        begin
          warn "  Raw message: #{message.inspect}"
        rescue StandardError
          nil
        end
        "#{FormatterConfig::MESSAGE_EMOJIS[:error]} [Message formatting error]"
      end
    end
  end
end
