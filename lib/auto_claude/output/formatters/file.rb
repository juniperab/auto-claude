# frozen_string_literal: true

module AutoClaude
  module Output
    module Formatters
      class File < Base
        def format(tool_name, input)
          case tool_name.downcase
          when "read"
            format_read(input)
          when "write"
            format_write(input)
          when "edit"
            format_edit(input)
          when "multiedit"
            format_multiedit(input)
          else
            "📄 File operation: #{tool_name}"
          end
        end

        private

        def format_read(input)
          path = extract_value(input, "file_path") || "unknown"
          offset = extract_value(input, "offset")
          limit = extract_value(input, "limit")
          lines = offset || limit ? " (lines #{offset}-#{limit})" : ""

          "#{FormatterConfig::TOOL_EMOJIS[:read]} Reading #{path}#{lines}"
        end

        def format_write(input)
          path = extract_value(input, "file_path") || "unknown"
          content = extract_value(input, "content") || ""
          indent = " " * FormatterConfig::STANDARD_INDENT
          size = if content.length > FormatterConfig::KB_SIZE
                   "\n#{indent}size: #{(content.length / FormatterConfig::KB_SIZE.to_f).round(1)}KB"
                 else
                   ""
                 end

          "#{FormatterConfig::TOOL_EMOJIS[:write]} Writing to #{path}#{size}"
        end

        def format_edit(input)
          path = extract_value(input, "file_path") || "unknown"
          "#{FormatterConfig::TOOL_EMOJIS[:edit]} Editing #{path}"
        end

        def format_multiedit(input)
          path = extract_value(input, "file_path") || "unknown"
          edits = extract_value(input, "edits") || []
          edit_count = edits.is_a?(Array) ? edits.length : 0
          indent = " " * FormatterConfig::STANDARD_INDENT

          "#{FormatterConfig::TOOL_EMOJIS[:multiedit]} Bulk editing #{path}\n#{indent}changes: #{edit_count} edits"
        end
      end
    end
  end
end
