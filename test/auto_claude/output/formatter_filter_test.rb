require 'test_helper'
require 'auto_claude/output/formatter'
require 'auto_claude/messages/base'

module AutoClaude
  module Output
    class FormatterFilterTest < Minitest::Test
      def setup
        @formatter = Formatter.new(color: false, truncate: false)
      end
      
      def test_filters_todo_success_message
        msg = create_tool_result("Todos have been modified successfully. Ensure that you continue to use the todo list to track your progress.")
        output = @formatter.format_message(msg)
        
        assert_nil output
      end
      
      def test_filters_todo_success_message_partial
        # Should filter even if the tail end changes
        msg = create_tool_result("Todos have been modified successfully. Some other text here.")
        output = @formatter.format_message(msg)
        
        assert_nil output
      end
      
      def test_filters_todo_list_updated_message
        msg = create_tool_result("Todo list has been updated with new tasks")
        output = @formatter.format_message(msg)
        
        assert_nil output
      end
      
      def test_filters_tasks_updated_message
        msg = create_tool_result("Tasks have been updated. Continue working on them.")
        output = @formatter.format_message(msg)
        
        assert_nil output
      end
      
      def test_does_not_filter_other_results
        msg = create_tool_result("Command completed successfully")
        output = @formatter.format_message(msg)
        
        refute_nil output
        assert_match(/📋 Result: Command completed successfully/, output)
      end
      
      def test_does_not_filter_error_results
        msg = create_tool_result("Todos have been modified successfully", is_error: true)
        output = @formatter.format_message(msg)
        
        refute_nil output
        assert_match(/⚠️ Error:/, output)
      end
      
      def test_does_not_filter_partial_matches
        msg = create_tool_result("The Todos have been modified successfully")
        output = @formatter.format_message(msg)
        
        refute_nil output
        assert_match(/📋 Result:/, output)
      end
      
      def test_filters_with_leading_whitespace
        msg = create_tool_result("  Todos have been modified successfully. Extra text.")
        output = @formatter.format_message(msg)
        
        assert_nil output
      end
      
      def test_should_filter_message_method
        assert @formatter.send(:should_filter_message?, "Todos have been modified successfully")
        assert @formatter.send(:should_filter_message?, "Todo list has been updated")
        assert @formatter.send(:should_filter_message?, "Tasks have been updated now")
        
        refute @formatter.send(:should_filter_message?, "Other message")
        refute @formatter.send(:should_filter_message?, "The Todos have been modified")
        refute @formatter.send(:should_filter_message?, nil)
        refute @formatter.send(:should_filter_message?, "")
      end
      
      def test_can_add_new_filter_prefix
        # Test that new prefixes can be added to the constant
        assert AutoClaude::Output::FormatterConfig::FILTERED_MESSAGE_PREFIXES.is_a?(Array)
        assert AutoClaude::Output::FormatterConfig::FILTERED_MESSAGE_PREFIXES.frozen?
        assert AutoClaude::Output::FormatterConfig::FILTERED_MESSAGE_PREFIXES.include?("Todos have been modified successfully")
      end
      
      private
      
      def create_tool_result(content, is_error: false)
        json = {
          "type" => "user",
          "message" => {
            "content" => [
              {
                "type" => "tool_result",
                "content" => content,
                "is_error" => is_error
              }
            ]
          }
        }
        Messages::Base.from_json(json)
      end
    end
  end
end