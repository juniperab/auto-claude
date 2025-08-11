module AutoClaude
    module Output
      class Formatter
        # Messages that should be filtered out (matched by prefix)
        FILTERED_MESSAGE_PREFIXES = [
          "Todos have been modified successfully",
          "Todo list has been updated",
          "Tasks have been updated"
        ].freeze
        
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
        rescue => e
          # Log the error with raw message for debugging
          $stderr.puts "⚠️  Warning: Failed to format message - #{e.class}: #{e.message}"
          $stderr.puts "  Raw message: #{message.inspect}" rescue nil
          
          # Return a safe fallback message
          "⚠️  [Message formatting error]"
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
          if tool && tool.start_with?("mcp__")
            format_mcp_tool(tool, input)
          else
            format_regular_tool(tool, input)
          end
        end

        def format_regular_tool(tool, input)
          # Ensure input is a Hash for safe navigation
          input = input.is_a?(Hash) ? input : {}
          
          case tool
          when "Bash", "bash"
            command = input&.dig("command") || input&.dig(:command) || "unknown"
            desc = input&.dig("description") || input&.dig(:description)
            if desc && command && command.length > 50
              "🖥️  Executing: #{desc}"
            else
              "🖥️  Running: #{command}"
            end
            
          when "Read", "read"
            path = input&.dig("file_path") || input&.dig(:file_path) || "unknown"
            offset = input&.dig("offset") || input&.dig(:offset)
            limit = input&.dig("limit") || input&.dig(:limit)
            lines = (offset || limit) ? " (lines #{offset}-#{limit})" : ""
            "👀 Reading #{path}#{lines}"
            
          when "Write", "write"
            path = input&.dig("file_path") || input&.dig(:file_path) || "unknown"
            content = input&.dig("content") || input&.dig(:content) || ""
            size = content && content.length > 1024 ? "\n  size: #{(content.length / 1024.0).round(1)}KB" : ""
            "✍️  Writing to #{path}#{size}"
            
          when "Edit", "edit"
            path = input&.dig("file_path") || input&.dig(:file_path) || "unknown"
            "✏️  Editing #{path}"
            
          when "MultiEdit", "multiedit"
            path = input&.dig("file_path") || input&.dig(:file_path) || "unknown"
            edits = input&.dig("edits") || input&.dig(:edits) || []
            "✂️  Bulk editing #{path}\n  changes: #{edits.length} edits"
            
          when "LS", "ls"
            path = input&.dig("path") || input&.dig(:path) || "."
            ignore = input&.dig("ignore") || input&.dig(:ignore)
            filter = ignore ? "\n  filter: excluding #{ignore}" : ""
            "📂 Listing #{path}/#{filter}"
            
          when "Glob", "glob"
            pattern = input&.dig("pattern") || input&.dig(:pattern) || "*"
            "🎯 Searching for #{pattern}"
            
          when "Grep", "grep"
            pattern = input&.dig("pattern") || input&.dig(:pattern) || ""
            path = input&.dig("path") || input&.dig(:path)
            context = extract_grep_context(input)
            location = path ? "\n  in: #{path}" : ""
            context_info = context ? "\n  context: ±#{context} lines" : ""
            "🔍 Searching for '#{pattern}'#{location}#{context_info}"
            
          when "WebSearch", "websearch"
            query = input&.dig("query") || input&.dig(:query) || ""
            "🔍 Web searching: '#{query}'"
            
          when "WebFetch", "webfetch"
            url = input&.dig("url") || input&.dig(:url) || ""
            prompt = input&.dig("prompt") || input&.dig(:prompt)
            domain = url&.include?('/') ? url.split('/')[2] : url
            domain ||= url
            analyzing = prompt && prompt.length > 0 ? "\n  analyzing: #{prompt[0..50]}..." : ""
            "🌍 Fetching #{domain}#{analyzing}"
            
          when "Task", "task"
            desc = input&.dig("description") || input&.dig(:description) || "task"
            agent = input&.dig("subagent_type") || input&.dig(:subagent_type) || "general"
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
          return "🔧 MCP Tool" unless tool
          
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
          return "" unless input
          
          query = input&.dig("query") || input&.dig(:query)
          if query
            "'#{query}'"
          elsif (repo = input&.dig("repo") || input&.dig(:repo)) && (owner = input&.dig("owner") || input&.dig(:owner))
            issue_num = input&.dig("issue_number") || input&.dig(:issue_number)
            pr_num = input&.dig("pull_number") || input&.dig(:pull_number)
            num = issue_num || pr_num
            num ? "#{owner}/#{repo}##{num}" : "#{owner}/#{repo}"
          elsif input.respond_to?(:keys) && input.keys&.length == 1
            input.values&.first.to_s
          elsif input.respond_to?(:empty?) && input.empty?
            ""
          elsif input.respond_to?(:keys) && input.keys&.any?
            "#{input.keys.first}: #{input.values.first}"
          else
            ""
          end
        end

        def humanize_action(action)
          # Convert snake_case to human readable
          return "Unknown" unless action
          action.to_s.gsub('_', ' ').split.map(&:capitalize).join(' ')
        end

        def format_todo_write(input)
          return "📝 Todo: empty list" unless input
          
          todos = input&.dig("todos") || input&.dig(:todos) || []
          
          if todos.nil? || todos.empty?
            return "📝 Todo: empty list"
          end
          
          # Count by status
          completed = todos.select { |t| (t&.dig("status") || t&.dig(:status)) == "completed" }
          in_progress = todos.select { |t| (t&.dig("status") || t&.dig(:status)) == "in_progress" }
          pending = todos.select { |t| (t&.dig("status") || t&.dig(:status)) == "pending" }
          
          # Build summary line
          if todos.length > 6
            summary = "📝 Todo: #{todos.length} tasks (#{completed.length} 🟢 | #{in_progress.length} 🔸 | #{pending.length} 🔹)"
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
            pending_count = items_to_show.count { |t| (t&.dig("status") || t&.dig(:status)) == "pending" }
            in_progress_count = items_to_show.count { |t| (t&.dig("status") || t&.dig(:status)) == "in_progress" }
            completed_count = items_to_show.count { |t| (t&.dig("status") || t&.dig(:status)) == "completed" }
            
            if pending.any? && pending[pending_count] && !items_to_show.include?(pending[pending_count])
              items_to_show << pending[pending_count]
            elsif in_progress.any? && in_progress[in_progress_count] && !items_to_show.include?(in_progress[in_progress_count])
              items_to_show << in_progress[in_progress_count]
            elsif completed.any? && completed_count < completed.length
              idx = completed.length - 1 - completed_count
              if idx >= 0 && completed[idx] && !items_to_show.include?(completed[idx])
                items_to_show << completed[idx]
              else
                break
              end
            else
              break
            end
          end
          
          # Format the selected items
          lines = [summary]
          items_to_show.each do |todo|
            status = todo&.dig("status") || todo&.dig(:status)
            status_icon = case status
                          when "completed" then "🟢"
                          when "in_progress" then "🔸"
                          else "🔹"
                          end
            content = todo&.dig("content") || todo&.dig(:content) || "unknown"
            lines << "  #{status_icon} #{content}"
          end
          
          lines.join("\n")
        end

        def format_tool_result(message)
          output = message.output || ""
          
          # Don't filter error messages, only filter successful results
          if !message.is_error && should_filter_message?(output)
            return nil
          end
          
          if message.is_error
            "⚠️  Error: #{truncate_text(output)}"
          else
            format_result_with_preview(output)
          end
        end
        
        def format_result_with_preview(output)
          # Ensure output is a string
          output_str = output.to_s
          
          # Handle edge case where to_s.lines might return nil
          lines = output_str.lines || []
          line_count = lines.length
          output_length = output_str.length
          size_kb = (output_length / 1024.0).round(1)
          
          # Check if this is a single Links line that needs special handling
          is_single_links_line = line_count == 1 && lines[0].to_s.match(/^Links:\s*\[/)
          
          # Build the header with stats
          header = if line_count == 0 || output_length == 0
            "📋 Result: (empty)"
          elsif line_count == 1 && output_length <= 100 && !is_single_links_line
            # Short single-line result - show inline (but not Links)
            "📋 Result: #{output_str.chomp}"
          else
            # Multi-line or long result - show stats
            "📋 Result: [#{line_count} lines, #{size_kb}KB]"
          end
          
          # For multi-line results or Links, show preview with special Links handling
          if line_count > 1 || (line_count == 1 && output_length > 100) || is_single_links_line
            formatted_lines = format_preview_lines(lines)
            result = [header] + formatted_lines[:lines]
            
            # Add ellipsis if needed
            if formatted_lines[:has_more]
              result << "  ..."
            end
            
            result.join("\n")
          else
            header
          end
        end
        
        def format_preview_lines(lines)
          preview_lines = []
          has_more = false
          line_index = 0
          max_preview_lines = 5
          
          while line_index < lines.length
            line = lines[line_index]
            
            # Check if this line contains a Links array
            if line.to_s.match(/^Links:\s*\[(.*)(\].*$)/)
              # Extract and format the links
              formatted_links = format_links_line(line.to_s)
              
              # For Links, we allow showing the header + 5 link items (6 lines total)
              # This is a special case since Links are important structured data
              if preview_lines.empty? && formatted_links[:lines].length > 1
                # Add header and up to 5 link items
                header_and_links = formatted_links[:lines].take(6)
                preview_lines.concat(header_and_links)
                
                # Check if we couldn't show all links
                if header_and_links.length < formatted_links[:lines].length || formatted_links[:has_more]
                  has_more = true
                end
              else
                # Not at start or no links, use normal limit
                remaining_slots = max_preview_lines - preview_lines.length
                if remaining_slots > 0
                  lines_to_add = formatted_links[:lines].take(remaining_slots)
                  preview_lines.concat(lines_to_add)
                  
                  if lines_to_add.length < formatted_links[:lines].length || formatted_links[:has_more]
                    has_more = true
                  end
                else
                  has_more = true
                end
              end
              
              # Check if there are more lines after this one
              if line_index < lines.length - 1
                has_more = true
              end
              
              # Stop processing after Links
              break
            else
              # Regular line
              if preview_lines.length < max_preview_lines
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
        
        def format_links_line(line)
          return { lines: ["  #{line.chomp}"], has_more: false } unless line.match(/^Links:\s*\[(.*)\]/)
          
          links_json = $1
          
          # Try to parse the JSON array
          begin
            # Handle empty array case
            if links_json.strip.empty?
              return { lines: ["  Links:"], has_more: false }
            end
            
            # Add brackets back and parse
            require 'json'
            links = JSON.parse("[#{links_json}]")
            
            formatted = ["  Links:"]
            links.take(5).each do |link|
              title = link["title"] || "Untitled"
              url = link["url"] || ""
              
              # Truncate title to 50 chars (47 chars + "...")
              title = title.length > 50 ? "#{title[0..46]}..." : title
              
              # Extract domain from URL
              domain = extract_domain(url)
              
              formatted << "    • #{title} (#{domain})"
            end
            
            has_more = links.length > 5
            
            { lines: formatted, has_more: has_more }
          rescue => e
            # If parsing fails, just return the original line
            { lines: ["  #{line.chomp}"], has_more: false }
          end
        end
        
        def extract_domain(url)
          return "unknown" if url.nil? || url.empty?
          
          # Extract domain from URL
          if url.match(%r{^https?://([^/]+)})
            domain = $1
            # Remove www. prefix if present
            domain = domain.sub(/^www\./, '')
            domain
          else
            "unknown"
          end
        end
        
        def should_filter_message?(text)
          return false if text.nil? || text.empty?
          
          # Check if the message starts with any filtered prefix
          FILTERED_MESSAGE_PREFIXES.any? do |prefix|
            text.strip.start_with?(prefix)
          end
        end

        def truncate_text(text, special_case: false)
          # Handle nil text
          return "" if text.nil?
          return text if special_case || !@truncate
          
          text_str = text.to_s
          lines = text_str.lines || []
          
          if lines.length > @max_lines
            truncated = lines.take(@max_lines).join.chomp
            truncated_count = lines.length - @max_lines
            "#{truncated}\n  (+ #{truncated_count} more lines...)"
          elsif text_str.length > 100 && lines.length == 1
            "#{text_str[0..100]}..."
          else
            text_str.chomp
          end
        end

        def extract_grep_context(input)
          return nil unless input
          
          # Check for context flags
          a = input&.dig("-A") || input&.dig(:"-A")
          b = input&.dig("-B") || input&.dig(:"-B") 
          c = input&.dig("-C") || input&.dig(:"-C")
          
          c || (a && b && a == b ? a : nil)
        end
      end
  end
end