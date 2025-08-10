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
          # Use new emoji format
          "👤 User: #{truncate_text(text)}"
        end

        def format_session_start(directory)
          "🚀 Session: starting in #{directory}"
        end

        def format_session_complete(tasks, duration, cost)
          "✅ Complete: #{tasks} tasks, #{duration}s, $#{'%.6f' % cost}"
        end

        def format_stats(tokens_up, tokens_down)
          "📊 Stats: #{tokens_up}↑ #{tokens_down}↓ tokens"
        end

        private

        def format_text_message(message)
          text = message.text || ""
          
          # Assistant messages with new emoji
          "💭 #{truncate_text(text, special_case: text.include?('TodoWrite'))}"
        end

        def format_tool_use(message)
          tool = message.tool_name
          input = message.tool_input || {}
          
          # Check if it's an MCP tool
          if tool.start_with?("mcp__")
            format_mcp_tool(tool, input)
          else
            format_regular_tool(tool, input)
          end
        end

        def format_regular_tool(tool, input)
          case tool
          when "Bash", "bash"
            command = input["command"] || input[:command] || "unknown"
            desc = input["description"] || input[:description]
            if desc && command.length > 50
              "🖥️  Executing: #{desc}"
            else
              "🖥️  Running: #{command}"
            end
            
          when "Read", "read"
            path = input["file_path"] || input[:file_path] || "unknown"
            lines = input["offset"] || input["limit"] ? " (lines #{input['offset']}-#{input['limit']})" : ""
            "👀 Reading #{path}#{lines}"
            
          when "Write", "write"
            path = input["file_path"] || input[:file_path] || "unknown"
            content = input["content"] || input[:content] || ""
            size = content.length > 1024 ? "\n  size: #{(content.length / 1024.0).round(1)}KB" : ""
            "✍️  Writing to #{path}#{size}"
            
          when "Edit", "edit"
            path = input["file_path"] || input[:file_path] || "unknown"
            "✏️  Editing #{path}"
            
          when "MultiEdit", "multiedit"
            path = input["file_path"] || input[:file_path] || "unknown"
            edits = input["edits"] || input[:edits] || []
            "✂️  Bulk editing #{path}\n  changes: #{edits.length} edits"
            
          when "LS", "ls"
            path = input["path"] || input[:path] || "."
            ignore = input["ignore"] || input[:ignore]
            filter = ignore ? "\n  filter: excluding #{ignore}" : ""
            "📂 Listing #{path}/#{filter}"
            
          when "Glob", "glob"
            pattern = input["pattern"] || input[:pattern] || "*"
            "🎯 Searching for #{pattern}"
            
          when "Grep", "grep"
            pattern = input["pattern"] || input[:pattern] || ""
            path = input["path"] || input[:path]
            context = extract_grep_context(input)
            location = path ? "\n  in: #{path}" : ""
            context_info = context ? "\n  context: ±#{context} lines" : ""
            "🔍 Searching for '#{pattern}'#{location}#{context_info}"
            
          when "WebSearch", "websearch"
            query = input["query"] || input[:query] || ""
            "🔍 Web searching: '#{query}'"
            
          when "WebFetch", "webfetch"
            url = input["url"] || input[:url] || ""
            prompt = input["prompt"] || input[:prompt]
            domain = url.split('/')[2] || url
            analyzing = prompt ? "\n  analyzing: #{prompt[0..50]}..." : ""
            "🌍 Fetching #{domain}#{analyzing}"
            
          when "Task", "task"
            desc = input["description"] || input[:description] || "task"
            agent = input["subagent_type"] || input[:subagent_type] || "general"
            "🤖 Delegating: #{desc}\n  agent: #{agent}"
            
          when "TodoWrite", "todowrite"
            format_todo_write(input)
            
          else
            # Unknown tool
            "🔧 #{tool}(...)"
          end
        end

        def format_mcp_tool(tool, input)
          # Parse MCP tool name: mcp__server__action
          parts = tool.split("__")
          server = parts[1] || "unknown"
          action = parts[2] || parts.last || "action"
          
          # Select emoji based on action keywords
          emoji = select_mcp_emoji(action)
          
          # Extract primary argument
          primary_arg = extract_mcp_primary_arg(action, input)
          
          # Format the display
          "#{emoji} #{humanize_action(action)}: #{primary_arg}\n  server: #{server}"
        end

        def select_mcp_emoji(action)
          action_lower = action.downcase
          
          case action_lower
          when /search|find/
            "🔍"
          when /get|fetch|read/
            "📥"
          when /list|index/
            "📃"
          when /create|add|new/
            "✨"
          when /delete|remove/
            "🗑️"
          when /update|edit|modify/
            "✏️"
          when /send|post|submit/
            "📤"
          else
            "🔧"
          end
        end

        def extract_mcp_primary_arg(action, input)
          # Smart selection of primary argument
          if input["query"] || input[:query]
            "'#{input['query'] || input[:query]}'"
          elsif (input["repo"] || input[:repo]) && (input["owner"] || input[:owner])
            owner = input["owner"] || input[:owner]
            repo = input["repo"] || input[:repo]
            issue_num = input["issue_number"] || input[:issue_number]
            pr_num = input["pull_number"] || input[:pull_number]
            num = issue_num || pr_num
            num ? "#{owner}/#{repo}##{num}" : "#{owner}/#{repo}"
          elsif input.keys.length == 1
            input.values.first.to_s
          elsif input.empty?
            ""
          else
            "#{input.keys.first}: #{input.values.first}"
          end
        end

        def humanize_action(action)
          # Convert snake_case to human readable
          action.gsub('_', ' ').split.map(&:capitalize).join(' ')
        end

        def format_todo_write(input)
          todos = input["todos"] || input[:todos] || []
          
          if todos.empty?
            return "📝 Todo: empty list"
          end
          
          # Count by status
          completed = todos.select { |t| (t["status"] || t[:status]) == "completed" }
          in_progress = todos.select { |t| (t["status"] || t[:status]) == "in_progress" }
          pending = todos.select { |t| (t["status"] || t[:status]) == "pending" }
          
          # Build summary line
          if todos.length > 6
            summary = "📝 Todo: #{todos.length} tasks (#{completed.length} ✅ | #{in_progress.length} 🔸 | #{pending.length} 🔹)"
          else
            summary = "📝 Todo: updating task list"
          end
          
          # Select 3 items to show: last completed, current in-progress, next pending
          items_to_show = []
          
          # Add last completed
          items_to_show << completed.last if completed.any?
          
          # Add current in-progress
          items_to_show << in_progress.first if in_progress.any?
          
          # Add next pending
          items_to_show << pending.first if pending.any?
          
          # Fill remaining slots if we have less than 3
          while items_to_show.length < 3 && items_to_show.length < todos.length
            # Try to add more in priority order
            if pending.any? && !items_to_show.include?(pending[items_to_show.count { |t| (t["status"] || t[:status]) == "pending" }])
              items_to_show << pending[items_to_show.count { |t| (t["status"] || t[:status]) == "pending" }]
            elsif in_progress.any? && !items_to_show.include?(in_progress[items_to_show.count { |t| (t["status"] || t[:status]) == "in_progress" }])
              items_to_show << in_progress[items_to_show.count { |t| (t["status"] || t[:status]) == "in_progress" }]
            elsif completed.any? && !items_to_show.include?(completed[completed.length - 1 - items_to_show.count { |t| (t["status"] || t[:status]) == "completed" }])
              items_to_show << completed[completed.length - 1 - items_to_show.count { |t| (t["status"] || t[:status]) == "completed" }]
            else
              break
            end
          end
          
          # Format the selected items
          lines = [summary]
          items_to_show.each do |todo|
            status_icon = case todo["status"] || todo[:status]
                          when "completed" then "✅"
                          when "in_progress" then "🔸"
                          else "🔹"
                          end
            lines << "  #{status_icon} #{todo['content'] || todo[:content]}"
          end
          
          lines.join("\n")
        end

        def format_tool_result(message)
          output = message.output || ""
          
          if message.is_error
            "⚠️  Error: #{truncate_text(output)}"
          elsif output.length > 200
            "📋 Result: [truncated, #{(output.length / 1024.0).round(1)}KB output]"
          else
            "📋 Result: #{truncate_text(output)}"
          end
        end

        def truncate_text(text, special_case: false)
          return text if special_case || !@truncate
          
          lines = text.to_s.lines
          if lines.length > @max_lines
            truncated = lines.take(@max_lines).join.chomp
            truncated_count = lines.length - @max_lines
            "#{truncated}\n  (+ #{truncated_count} more lines...)"
          elsif text.length > 100 && lines.length == 1
            "#{text[0..100]}..."
          else
            text.chomp
          end
        end

        def extract_grep_context(input)
          # Check for context flags
          a = input["-A"] || input[:"-A"]
          b = input["-B"] || input[:"-B"] 
          c = input["-C"] || input[:"-C"]
          
          c || (a && b && a == b ? a : nil)
        end
      end
  end
end