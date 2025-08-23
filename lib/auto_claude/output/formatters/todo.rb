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
          target_total = 5
          
          # Ideal distribution: 2 completed, 1 in_progress, 2 pending
          completed_target = 2
          in_progress_target = 1
          pending_target = 2
          
          # Get available counts
          completed_available = stats[:completed].length
          in_progress_available = stats[:in_progress].length
          pending_available = stats[:pending].length
          
          # Calculate actual amounts to show
          completed_to_show = [completed_target, completed_available].min
          in_progress_to_show = [in_progress_target, in_progress_available].min
          pending_to_show = [pending_target, pending_available].min
          
          # If we have fewer than 5 total, try to fill from other categories
          total_shown = completed_to_show + in_progress_to_show + pending_to_show
          remaining_slots = target_total - total_shown
          
          if remaining_slots > 0
            # Try to fill from pending first
            extra_pending = [remaining_slots, pending_available - pending_to_show].min
            pending_to_show += extra_pending
            remaining_slots -= extra_pending
            
            # Then from completed
            if remaining_slots > 0
              extra_completed = [remaining_slots, completed_available - completed_to_show].min
              completed_to_show += extra_completed
              remaining_slots -= extra_completed
            end
            
            # Finally from in_progress
            if remaining_slots > 0
              extra_in_progress = [remaining_slots, in_progress_available - in_progress_to_show].min
              in_progress_to_show += extra_in_progress
            end
          end
          
          # Add the items: last N completed, first in_progress, first N pending
          if completed_to_show > 0
            items.concat(stats[:completed].last(completed_to_show))
          end
          
          if in_progress_to_show > 0
            items.concat(stats[:in_progress].first(in_progress_to_show))
          end
          
          if pending_to_show > 0
            items.concat(stats[:pending].first(pending_to_show))
          end
          
          items
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