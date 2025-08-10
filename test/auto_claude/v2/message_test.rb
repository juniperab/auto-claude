require "test_helper"
require "auto_claude/v2/messages/base"

class AutoClaude::V2::MessageTest < Minitest::Test
  def test_parse_text_message
    json = {
      "type" => "assistant",
      "message" => {
        "content" => [
          {"type" => "text", "text" => "Hello world"}
        ]
      }
    }
    
    message = AutoClaude::V2::Messages::Base.from_json(json)
    
    assert_kind_of AutoClaude::V2::Messages::TextMessage, message
    assert_equal "Hello world", message.text
    assert_equal "assistant", message.role
  end

  def test_parse_tool_use_message
    json = {
      "type" => "assistant",
      "message" => {
        "content" => [
          {
            "type" => "tool_use",
            "name" => "Bash",
            "input" => {"command" => "ls -la"}
          }
        ]
      }
    }
    
    message = AutoClaude::V2::Messages::Base.from_json(json)
    
    assert_kind_of AutoClaude::V2::Messages::ToolUseMessage, message
    assert_equal "Bash", message.tool_name
    assert_equal({"command" => "ls -la"}, message.tool_input)
  end

  def test_parse_tool_result_message
    json = {
      "type" => "user",
      "message" => {
        "content" => [
          {
            "type" => "tool_result",
            "tool_use_id" => "bash_123",
            "content" => "file1.txt\nfile2.txt",
            "is_error" => false
          }
        ]
      }
    }
    
    message = AutoClaude::V2::Messages::Base.from_json(json)
    
    assert_kind_of AutoClaude::V2::Messages::ToolResultMessage, message
    assert_equal "bash_123", message.tool_name
    assert_equal "file1.txt\nfile2.txt", message.output
    assert_equal false, message.is_error
  end

  def test_parse_result_success_message
    json = {
      "type" => "result",
      "subtype" => "success",
      "result" => "Task completed",
      "success" => true,
      "num_turns" => 2,
      "duration_ms" => 1500,
      "total_cost_usd" => 0.002,
      "usage" => {
        "input_tokens" => 100,
        "output_tokens" => 50
      },
      "session_id" => "abc123"
    }
    
    message = AutoClaude::V2::Messages::Base.from_json(json)
    
    assert_kind_of AutoClaude::V2::Messages::ResultMessage, message
    assert_equal "Task completed", message.content
    assert message.success?
    refute message.error?
    assert_equal 2, message.metadata["num_turns"]
    assert_equal 0.002, message.metadata["total_cost_usd"]
    assert_equal "abc123", message.metadata["session_id"]
  end

  def test_parse_result_error_message
    json = {
      "type" => "result",
      "is_error" => true,
      "result" => "Rate limit exceeded",
      "error" => {
        "message" => "Too many requests"
      }
    }
    
    message = AutoClaude::V2::Messages::Base.from_json(json)
    
    assert_kind_of AutoClaude::V2::Messages::ResultMessage, message
    assert_equal "Rate limit exceeded", message.content
    refute message.success?
    assert message.error?
    assert_equal "Rate limit exceeded", message.error_message
  end

  def test_parse_system_message
    json = {
      "type" => "system",
      "message" => "System information"
    }
    
    message = AutoClaude::V2::Messages::Base.from_json(json)
    
    assert_kind_of AutoClaude::V2::Messages::SystemMessage, message
    assert_equal "System information", message.message
  end

  def test_parse_unknown_message
    json = {
      "type" => "unknown_type",
      "data" => "something"
    }
    
    message = AutoClaude::V2::Messages::Base.from_json(json)
    
    assert_kind_of AutoClaude::V2::Messages::UnknownMessage, message
    assert_equal "unknown_type", message.type
    assert_equal json, message.raw_json
  end

  def test_message_timestamp
    json = {"type" => "system", "message" => "test"}
    
    time_before = Time.now
    message = AutoClaude::V2::Messages::Base.from_json(json)
    time_after = Time.now
    
    assert message.timestamp >= time_before
    assert message.timestamp <= time_after
  end

  def test_message_to_h
    json = {
      "type" => "assistant",
      "message" => {
        "content" => [{"type" => "text", "text" => "Hello"}]
      }
    }
    
    message = AutoClaude::V2::Messages::Base.from_json(json)
    assert_equal json, message.to_h
  end

  def test_handle_nil_input
    assert_nil AutoClaude::V2::Messages::Base.from_json(nil)
  end

  def test_handle_non_hash_input
    assert_nil AutoClaude::V2::Messages::Base.from_json("string")
    assert_nil AutoClaude::V2::Messages::Base.from_json([])
    assert_nil AutoClaude::V2::Messages::Base.from_json(123)
  end
end