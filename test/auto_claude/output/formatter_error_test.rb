require 'test_helper'
require 'auto_claude/output/formatter'
require 'auto_claude/messages/base'

module AutoClaude
  module Output
    class FormatterErrorTest < Minitest::Test
      def setup
        @formatter = Formatter.new(color: false, truncate: false)
      end
      
      def test_format_message_with_nil_input
        # Create a tool use message with nil input
        json = {
          "type" => "tool_use",
          "id" => "toolu_test123",
          "name" => "Bash",
          "input" => nil
        }
        msg = Messages::Base.from_json(json)
        
        # Should not raise error, should handle gracefully
        output = @formatter.format_message(msg)
        refute_nil output
        assert_match(/🖥️  Running: unknown/, output)
      end
      
      def test_format_message_with_missing_keys
        # Create a tool use message with missing expected keys
        json = {
          "type" => "tool_use",
          "id" => "toolu_test123",
          "name" => "Write",
          "input" => {"unexpected_key" => "value"}
        }
        msg = Messages::Base.from_json(json)
        
        output = @formatter.format_message(msg)
        refute_nil output
        assert_match(/✍️  Writing to unknown/, output)
      end
      
      def test_format_todo_with_nil_todos
        json = {
          "type" => "tool_use",
          "id" => "toolu_test123",
          "name" => "TodoWrite",
          "input" => nil
        }
        msg = Messages::Base.from_json(json)
        
        output = @formatter.format_message(msg)
        refute_nil output
        assert_match(/📝 Todo: empty list/, output)
      end
      
      def test_format_todo_with_malformed_todos
        json = {
          "type" => "tool_use",
          "id" => "toolu_test123",
          "name" => "TodoWrite",
          "input" => {
            "todos" => [
              nil,
              {"content" => "Valid todo", "status" => "pending"},
              {"missing_content" => true, "status" => "completed"}
            ]
          }
        }
        msg = Messages::Base.from_json(json)
        
        # Should handle nil and missing content gracefully
        output = @formatter.format_message(msg)
        refute_nil output
        assert_match(/📝 Todo:/, output)
      end
      
      def test_format_mcp_tool_with_nil_input
        json = {
          "type" => "tool_use",
          "id" => "toolu_test123",
          "name" => "mcp__vault__search",
          "input" => nil
        }
        msg = Messages::Base.from_json(json)
        
        output = @formatter.format_message(msg)
        refute_nil output
        # Should show MCP tool with empty args
        assert_match(/Search:/, output)
        assert_match(/server: vault/, output)
      end
      
      def test_format_message_catches_exceptions
        # Create a message that will cause an error during formatting
        # by creating a mock that raises when accessed
        mock_message = Object.new
        def mock_message.type; raise "Intentional error"; end
        def mock_message.inspect; "#<MockMessage>"; end
        
        # Capture stderr to verify error was logged
        original_stderr = $stderr
        captured_stderr = StringIO.new
        $stderr = captured_stderr
        
        output = @formatter.format_message(mock_message)
        
        $stderr = original_stderr
        
        # Should return error message
        assert_equal "⚠️  [Message formatting error]", output
        
        # Should have logged to stderr
        stderr_output = captured_stderr.string
        assert_match(/Warning: Failed to format message/, stderr_output)
        assert_match(/Intentional error/, stderr_output)
      end
      
      def test_format_grep_with_nil_context_flags
        json = {
          "type" => "tool_use",
          "id" => "toolu_test123",
          "name" => "Grep",
          "input" => {
            "pattern" => "test",
            "-C" => nil
          }
        }
        msg = Messages::Base.from_json(json)
        
        output = @formatter.format_message(msg)
        refute_nil output
        assert_match(/🔍 Searching for 'test'/, output)
        refute_match(/context:/, output) # Should not show context if nil
      end
      
      def test_format_websearch_with_non_hash_input
        # While this shouldn't happen in practice, ensure we handle it
        json = {
          "type" => "tool_use",
          "id" => "toolu_test123",
          "name" => "WebSearch",
          "input" => "not a hash"
        }
        # This might fail at message creation, so catch that
        begin
          msg = Messages::Base.from_json(json)
          output = @formatter.format_message(msg)
          refute_nil output
        rescue => e
          # If message creation fails, that's also acceptable
          assert_kind_of StandardError, e
        end
      end
    end
  end
end