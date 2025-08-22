require 'test_helper'
require 'auto_claude/output/formatters/todo'
require 'auto_claude/output/formatter_config'

module AutoClaude
  module Output
    module Formatters
      class TodoTest < Minitest::Test
        def setup
          @config = FormatterConfig.new
          @formatter = Todo.new(@config)
        end
        
        def test_format_empty_list
          input = { "todos" => [] }
          result = @formatter.format(input)
          
          assert_equal "📝 Todo: empty list", result
        end
        
        def test_format_nil_todos
          input = { "todos" => nil }
          result = @formatter.format(input)
          
          assert_equal "📝 Todo: empty list", result
        end
        
        def test_format_no_todos_key
          input = {}
          result = @formatter.format(input)
          
          assert_equal "📝 Todo: empty list", result
        end
        
        def test_format_few_tasks
          input = {
            "todos" => [
              { "content" => "Task 1", "status" => "pending" },
              { "content" => "Task 2", "status" => "in_progress" },
              { "content" => "Task 3", "status" => "completed" }
            ]
          }
          result = @formatter.format(input)
          
          assert_match(/📝 Todo: updating task list/, result)
          assert_match(/\[x\] Task 3/, result)
          assert_match(/\[-\] Task 2/, result)
          assert_match(/\[ \] Task 1/, result)
        end
        
        def test_format_many_tasks
          todos = []
          5.times { |i| todos << { "content" => "Pending #{i}", "status" => "pending" } }
          3.times { |i| todos << { "content" => "Progress #{i}", "status" => "in_progress" } }
          4.times { |i| todos << { "content" => "Done #{i}", "status" => "completed" } }
          
          input = { "todos" => todos }
          result = @formatter.format(input)
          
          # Should show summary with counts
          assert_match(/📝 Todo: 12 tasks \(4 completed\)/, result)
          
          # Should show selected items
          lines = result.split("\n")
          assert lines.length <= 4  # Summary + up to 3 items
        end
        
        def test_format_handles_nil_todo_items
          input = {
            "todos" => [
              nil,
              { "content" => "Valid task", "status" => "pending" },
              nil,
              { "content" => "Another task", "status" => "completed" }
            ]
          }
          result = @formatter.format(input)
          
          # Should skip nil items
          assert_match(/Valid task/, result)
          assert_match(/Another task/, result)
          refute_match(/unknown.*unknown/, result)  # Shouldn't have multiple unknowns
        end
        
        def test_format_handles_malformed_todo_items
          input = {
            "todos" => [
              { "status" => "pending" },  # Missing content
              { "content" => "Task without status" },  # Missing status
              { "wrong_key" => "value" },  # Wrong structure
              { "content" => "Good task", "status" => "completed" }
            ]
          }
          result = @formatter.format(input)
          
          # Should handle missing fields gracefully
          assert_match(/unknown/, result)  # Missing content shows as unknown
          assert_match(/Good task/, result)
          # Note: "Task without status" might not appear due to selection logic
          # (shows last completed, first in_progress, first pending)
        end
        
        def test_format_with_symbol_keys
          input = {
            todos: [
              { content: "Task 1", status: "pending" },
              { content: "Task 2", status: "in_progress" }
            ]
          }
          result = @formatter.format(input)
          
          assert_match(/Task 1/, result)
          assert_match(/Task 2/, result)
        end
        
        def test_format_unknown_status
          input = {
            "todos" => [
              { "content" => "Task", "status" => "unknown_status" }
            ]
          }
          result = @formatter.format(input)
          
          # Should show the task (even though it doesn't match any status filter)
          assert_match(/📝 Todo: updating task list/, result)
          # The task won't be shown because it doesn't match pending/in_progress/completed
          # This is expected behavior - unknown statuses are filtered out
        end
        
        def test_display_item_selection
          # Test that it shows last completed, current in-progress, next pending
          input = {
            "todos" => [
              { "content" => "Done 1", "status" => "completed" },
              { "content" => "Done 2", "status" => "completed" },
              { "content" => "Current", "status" => "in_progress" },
              { "content" => "Pending 1", "status" => "pending" },
              { "content" => "Pending 2", "status" => "pending" }
            ]
          }
          result = @formatter.format(input)
          
          # Should show Done 2 (last completed), Current, and Pending 1 (next pending)
          assert_match(/Done 2/, result)
          assert_match(/Current/, result) 
          assert_match(/Pending 1/, result)
          
          # Should not show Done 1 or Pending 2
          refute_match(/Done 1/, result)
          refute_match(/Pending 2/, result)
        end
        
        def test_format_with_nil_input
          result = @formatter.format(nil)
          
          assert_equal "📝 Todo: empty list", result
        end
        
        def test_exactly_at_max_display_threshold
          todos = Array.new(6) { |i| { "content" => "Task #{i}", "status" => "pending" } }
          input = { "todos" => todos }
          result = @formatter.format(input)
          
          # At exactly 6 tasks, should still show "updating task list"
          assert_match(/📝 Todo: updating task list/, result)
        end
        
        def test_just_over_max_display_threshold
          todos = Array.new(7) { |i| { "content" => "Task #{i}", "status" => "pending" } }
          input = { "todos" => todos }
          result = @formatter.format(input)
          
          # At 7 tasks, should show summary with counts
          assert_match(/📝 Todo: 7 tasks/, result)
        end
      end
    end
  end
end