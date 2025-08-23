# frozen_string_literal: true

require "test_helper"
require "auto_claude/messages/base"

module AutoClaude
  module Messages
    class ToolUseMessageTest < Minitest::Test
      def test_direct_tool_use_message
        json = {
          "type" => "tool_use",
          "id" => "toolu_01ABC123",
          "name" => "Write",
          "input" => {
            "file_path" => "/path/to/file.rb",
            "content" => "puts 'hello'"
          }
        }

        msg = Base.from_json(json)

        assert_instance_of ToolUseMessage, msg
        assert_equal "tool_use", msg.type
        assert_equal "toolu_01ABC123", msg.tool_id
        assert_equal "Write", msg.tool_name
        assert_equal "/path/to/file.rb", msg.tool_input["file_path"]
        assert_equal "puts 'hello'", msg.tool_input["content"]
      end

      def test_nested_tool_use_in_assistant_message
        json = {
          "type" => "assistant",
          "message" => {
            "content" => [
              {
                "type" => "tool_use",
                "id" => "toolu_02XYZ",
                "name" => "Grep",
                "input" => {
                  "pattern" => "TODO",
                  "path" => "/src"
                }
              }
            ]
          }
        }

        msg = Base.from_json(json)

        assert_instance_of ToolUseMessage, msg
        assert_equal "assistant", msg.type
        assert_equal "toolu_02XYZ", msg.tool_id
        assert_equal "Grep", msg.tool_name
        assert_equal "TODO", msg.tool_input["pattern"]
        assert_equal "/src", msg.tool_input["path"]
      end

      def test_mcp_tool_use
        json = {
          "type" => "tool_use",
          "id" => "toolu_03MCP",
          "name" => "mcp__code-server__search_code",
          "input" => {
            "query" => "authentication",
            "scope" => "optimal"
          }
        }

        msg = Base.from_json(json)

        assert_instance_of ToolUseMessage, msg
        assert_equal "mcp__code-server__search_code", msg.tool_name
        assert_equal "authentication", msg.tool_input["query"]
        assert_equal "optimal", msg.tool_input["scope"]
      end

      def test_tool_use_with_empty_input
        json = {
          "type" => "tool_use",
          "id" => "toolu_04EMPTY",
          "name" => "EmptyTool",
          "input" => {}
        }

        msg = Base.from_json(json)

        assert_instance_of ToolUseMessage, msg
        assert_equal "EmptyTool", msg.tool_name
        assert_empty msg.tool_input
      end

      def test_tool_use_missing_fields
        json = {
          "type" => "tool_use",
          "name" => "SomeTool"
          # Missing id and input
        }

        msg = Base.from_json(json)

        assert_instance_of ToolUseMessage, msg
        assert_equal "SomeTool", msg.tool_name
        assert_equal "", msg.tool_id
        assert_empty msg.tool_input
      end
    end
  end
end
