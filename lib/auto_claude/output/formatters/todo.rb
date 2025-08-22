module AutoClaude
  module Output
    module Formatters
      class Todo < Base
        def format(input)
          todos = extract_value(input, "todos") || []
          
          return "#{FormatterConfig::TOOL_EMOJIS[:todowrite]} Todo: empty list" if todos.nil? || todos.empty?
          
          stats = calculate_stats(todos)
          summary = build_summary(stats, todos.length)
          items = select_display_items(todos, stats)
          
          format_output(summary, items)
        end
        
        private
        
        def calculate_stats(todos)
          {
            completed: filter_by_status(todos, "completed"),
            in_progress: filter_by_status(todos, "in_progress"),
            pending: filter_by_status(todos, "pending")
          }
        end
        
        def filter_by_status(todos, status)
          todos.select do |t|
            next false if t.nil? || !t.is_a?(Hash)
            (t["status"] || t[:status]) == status
          end
        end
        
        def build_summary(stats, total)
          emoji = FormatterConfig::TOOL_EMOJIS[:todowrite]
          
          if total > FormatterConfig::MAX_TODO_DISPLAY
            completed_count = stats[:completed].length
            "#{emoji} Todo: #{total} tasks (#{completed_count} completed)"
          else
            "#{emoji} Todo: updating task list"
          end
        end
        
        def select_display_items(todos, stats)
          items = []
          
          # Add last completed, current in-progress, next pending
          items << stats[:completed].last if stats[:completed].any?
          items << stats[:in_progress].first if stats[:in_progress].any?
          items << stats[:pending].first if stats[:pending].any?
          
          # Fill remaining slots
          fill_remaining_slots(items, todos, stats)
          
          items
        end
        
        def fill_remaining_slots(items, todos, stats)
          while items.length < 3 && items.length < todos.length
            added = false
            
            [:pending, :in_progress, :completed].each do |status|
              status_items = stats[status]
              next if status_items.empty?
              
              candidate = status_items.find { |t| !items.include?(t) }
              if candidate
                items << candidate
                added = true
                break
              end
            end
            
            break unless added
          end
        end
        
        def format_output(summary, items)
          lines = [summary]
          
          items.each do |todo|
            next if todo.nil?
            status = todo["status"] || todo[:status] if todo.is_a?(Hash)
            icon = FormatterConfig::TODO_STATUS_ICONS[status] || "[ ]"
            content = todo["content"] || todo[:content] || "unknown" if todo.is_a?(Hash)
            content ||= "unknown"
            lines << "  #{icon} #{content}"
          end
          
          lines.join("\n")
        end
      end
    end
  end
end