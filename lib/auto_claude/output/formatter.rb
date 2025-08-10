module AutoClaude
    module Output
      class Formatter
        def initialize(color: true, truncate: true, max_lines: 5)
          @color = color
          @truncate = truncate
          @max_lines = max_lines
        end

        def format_message(message)
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
        end

        def format_user_prompt(text)
          lines = text.to_s.lines
          
          if @truncate && lines.length > @max_lines
            truncated = lines.take(@max_lines).join
            truncated_count = lines.length - @max_lines
            "  #{truncated.chomp}\n    + #{truncated_count} lines not shown"
          else
            "  #{text}"
          end
        end

        private

        def format_text_message(message)
          text = message.text || ""
          lines = text.lines
          
          # Special case: Don't truncate TodoWrite tool
          should_truncate = @truncate && !text.include?("TodoWrite")
          
          if should_truncate && lines.length > @max_lines
            truncated = lines.take(@max_lines).map { |l| "  #{l}" }.join
            truncated_count = lines.length - @max_lines
            "#{truncated.chomp}\n    + #{truncated_count} line#{'s' if truncated_count != 1} not shown"
          else
            lines.map { |l| "  #{l}" }.join.chomp
          end
        end

        def format_tool_use(message)
          tool = message.tool_name
          input = message.tool_input
          
          # Format based on tool type
          case tool
          when "Bash", "bash"
            command = input["command"] || input[:command] || "unknown"
            "  #{tool}(\"#{command}\")"
          when "Read", "read"
            path = input["file_path"] || input[:file_path] || "unknown"
            "  #{tool}(\"#{path}\")"
          when "Write", "write", "Edit", "edit"
            path = input["file_path"] || input[:file_path] || "unknown"
            "  #{tool}(\"#{path}\")"
          when "TodoWrite"
            # Show full todo content without truncation
            todos = input["todos"] || input[:todos] || []
            if todos.any?
              todo_lines = todos.map do |todo|
                status_icon = case todo["status"] || todo[:status]
                              when "completed" then "✓"
                              when "in_progress" then "→"
                              else "○"
                              end
                "    #{status_icon} #{todo['content'] || todo[:content]}"
              end
              "  #{tool}:\n#{todo_lines.join("\n")}"
            else
              "  #{tool}"
            end
          else
            # Generic tool format
            "  #{tool}(...)"
          end
        end

        def format_tool_result(message)
          output = message.output || ""
          lines = output.lines
          
          if message.is_error
            "  Error: #{output}"
          elsif @truncate && lines.length > @max_lines
            truncated = lines.take(@max_lines).map { |l| "  #{l}" }.join
            truncated_count = lines.length - @max_lines
            "#{truncated.chomp}\n    + #{truncated_count} line#{'s' if truncated_count != 1} not shown"
          else
            lines.map { |l| "  #{l}" }.join.chomp
          end
        end
      end
  end
end