require 'test_helper'
require 'auto_claude/output/formatter'
require 'auto_claude/messages/base'

module AutoClaude
  module Output
    class FormatterNilTest < Minitest::Test
      def setup
        @formatter = Formatter.new(color: false, truncate: false)
      end
      
      def test_format_tool_use_with_nil_input
        msg = create_tool_message_with_nil_input("Write")
        output = @formatter.format_message(msg)
        
        assert_match(/✍️ Writing to unknown/, output)
        refute_match(/undefined method/, output)
      end
      
      def test_format_tool_use_with_nil_tool_name
        msg = create_tool_message_with_nil_name
        output = @formatter.format_message(msg)
        
        assert output # Should not crash
        refute_match(/undefined method/, output)
      end
      
      def test_format_bash_with_nil_command
        msg = create_tool_message("Bash", nil)
        output = @formatter.format_message(msg)
        
        assert_match(/🖥️ Running: unknown/, output)
      end
      
      def test_format_grep_with_nil_input
        msg = create_tool_message("Grep", nil)
        output = @formatter.format_message(msg)
        
        assert_match(/🔍 Searching for ''/, output)
      end
      
      def test_format_webfetch_with_nil_url
        msg = create_tool_message("WebFetch", {})
        output = @formatter.format_message(msg)
        
        assert_match(/🌍 Fetching/, output)
        refute_match(/undefined method/, output)
      end
      
      def test_format_multiedit_with_nil_edits
        msg = create_tool_message("MultiEdit", {"file_path" => "/test.rb"})
        output = @formatter.format_message(msg)
        
        assert_match(/✂️ Bulk editing \/test.rb/, output)
        assert_match(/changes: 0 edits/, output)
      end
      
      def test_format_mcp_tool_with_nil_input
        msg = create_tool_message("mcp__test-server__search", nil)
        output = @formatter.format_message(msg)
        
        assert_match(/🔍 Search:/, output)
        assert_match(/server: test-server/, output)
      end
      
      def test_format_mcp_tool_with_nil_tool_name
        msg = create_tool_message_with_nil_name
        msg.instance_variable_set(:@tool_name, nil)
        output = @formatter.format_message(msg)
        
        assert output # Should not crash
      end
      
      def test_format_todo_write_with_nil_input
        msg = create_tool_message("TodoWrite", nil)
        output = @formatter.format_message(msg)
        
        assert_match(/📝 Todo: empty list/, output)
      end
      
      def test_format_todo_write_with_nil_todos
        msg = create_tool_message("TodoWrite", {})
        output = @formatter.format_message(msg)
        
        assert_match(/📝 Todo: empty list/, output)
      end
      
      def test_format_todo_write_with_todo_missing_content
        msg = create_tool_message("TodoWrite", {
          "todos" => [
            {"status" => "completed"},
            {"content" => "Task 2", "status" => "pending"}
          ]
        })
        output = @formatter.format_message(msg)
        
        assert_match(/📝 Todo: updating task list/, output)
        assert_match(/Task 2/, output)
      end
      
      def test_extract_grep_context_with_nil_input
        search_formatter = Formatters::Search.new
        context = search_formatter.send(:extract_grep_context, nil)
        assert_nil context
      end
      
      def test_extract_mcp_primary_arg_with_nil_input
        mcp_formatter = Formatters::Mcp.new
        arg = mcp_formatter.send(:extract_primary_arg, "search", nil)
        assert_equal "", arg
      end
      
      def test_humanize_action_with_nil
        mcp_formatter = Formatters::Mcp.new
        result = mcp_formatter.send(:humanize_action, nil)
        assert_equal "Unknown", result
      end
      
      private
      
      def create_tool_message(tool_name, input)
        json = {
          "type" => "tool_use",
          "id" => "toolu_test",
          "name" => tool_name,
          "input" => input
        }
        Messages::Base.from_json(json)
      end
      
      def create_tool_message_with_nil_input(tool_name)
        msg = Messages::ToolUseMessage.new({"type" => "tool_use"})
        msg.instance_variable_set(:@tool_name, tool_name)
        msg.instance_variable_set(:@tool_input, nil)
        msg
      end
      
      def create_tool_message_with_nil_name
        msg = Messages::ToolUseMessage.new({"type" => "tool_use"})
        msg.instance_variable_set(:@tool_name, nil)
        msg.instance_variable_set(:@tool_input, {})
        msg
      end
    end
  end
end