# frozen_string_literal: true

require "test_helper"
require "auto_claude/session"
require "auto_claude/output/memory"

module AutoClaude
  class SessionTest < Minitest::Test
    def setup
      @output = Output::Memory.new
      @session = Session.new(
        directory: Dir.pwd,
        output: @output,
        claude_options: []
      )
    end

    def test_tracks_session_id_from_first_message
      # Create a system message with session_id
      system_message = Messages::SystemMessage.new({
        "type" => "system",
        "message" => "init",
        "session_id" => "session-123"
      })

      @session.send(:handle_message, system_message)

      assert_equal "session-123", @session.session_id
    end

    def test_updates_session_id_when_it_changes
      # First message with initial session_id
      message1 = Messages::TextMessage.new({
        "type" => "assistant",
        "message" => { "content" => [{ "type" => "text", "text" => "Hello" }] },
        "session_id" => "session-123"
      })

      @session.send(:handle_message, message1)
      assert_equal "session-123", @session.session_id

      # Second message with different session_id
      message2 = Messages::TextMessage.new({
        "type" => "assistant",
        "message" => { "content" => [{ "type" => "text", "text" => "World" }] },
        "session_id" => "session-456"
      })

      @session.send(:handle_message, message2)
      assert_equal "session-456", @session.session_id
    end

    def test_session_id_persists_when_message_has_no_session_id
      # First message with session_id
      message1 = Messages::TextMessage.new({
        "type" => "assistant",
        "message" => { "content" => [{ "type" => "text", "text" => "Hello" }] },
        "session_id" => "session-789"
      })

      @session.send(:handle_message, message1)
      assert_equal "session-789", @session.session_id

      # Second message without session_id
      message2 = Messages::TextMessage.new({
        "type" => "assistant",
        "message" => { "content" => [{ "type" => "text", "text" => "World" }] }
      })

      @session.send(:handle_message, message2)
      # Session ID should remain unchanged
      assert_equal "session-789", @session.session_id
    end

    def test_result_message_updates_session_id
      # Initial message with session_id
      message1 = Messages::TextMessage.new({
        "type" => "assistant",
        "message" => { "content" => [{ "type" => "text", "text" => "Processing" }] },
        "session_id" => "session-initial"
      })

      @session.send(:handle_message, message1)
      assert_equal "session-initial", @session.session_id

      # Result message with different session_id
      result = Messages::ResultMessage.new({
        "type" => "result",
        "subtype" => "success",
        "result" => "Done",
        "success" => true,
        "session_id" => "session-final"
      })

      @session.send(:handle_message, result)
      assert_equal "session-final", @session.session_id
    end

    def test_handles_nil_session_id_gracefully
      # Message without session_id
      message = Messages::TextMessage.new({
        "type" => "assistant",
        "message" => { "content" => [{ "type" => "text", "text" => "No session" }] }
      })

      @session.send(:handle_message, message)
      assert_nil @session.session_id
    end

    def test_tracks_token_usage_per_model
      # First message from model A
      message1 = Messages::TextMessage.new({
        "type" => "assistant",
        "message" => {
          "content" => [{ "type" => "text", "text" => "Hello" }],
          "model" => "claude-opus",
          "usage" => {
            "input_tokens" => 10,
            "output_tokens" => 20,
            "cache_creation_input_tokens" => 100,
            "cache_read_input_tokens" => 50
          }
        }
      })

      @session.send(:handle_message, message1)

      # Second message from same model
      message2 = Messages::TextMessage.new({
        "type" => "assistant",
        "message" => {
          "content" => [{ "type" => "text", "text" => "World" }],
          "model" => "claude-opus",
          "usage" => {
            "input_tokens" => 5,
            "output_tokens" => 15
          }
        }
      })

      @session.send(:handle_message, message2)

      # Third message from different model
      message3 = Messages::TextMessage.new({
        "type" => "assistant",
        "message" => {
          "content" => [{ "type" => "text", "text" => "Hi" }],
          "model" => "claude-haiku",
          "usage" => {
            "input_tokens" => 3,
            "output_tokens" => 7
          }
        }
      })

      @session.send(:handle_message, message3)

      # Check opus totals
      opus_usage = @session.model_token_usage["claude-opus"]
      assert_equal 15, opus_usage[:input]  # 10 + 5
      assert_equal 35, opus_usage[:output] # 20 + 15
      assert_equal 100, opus_usage[:cache_creation]
      assert_equal 50, opus_usage[:cache_read]
      assert_equal 2, opus_usage[:count]

      # Check haiku totals
      haiku_usage = @session.model_token_usage["claude-haiku"]
      assert_equal 3, haiku_usage[:input]
      assert_equal 7, haiku_usage[:output]
      assert_equal 0, haiku_usage[:cache_creation]
      assert_equal 0, haiku_usage[:cache_read]
      assert_equal 1, haiku_usage[:count]

      # Check combined totals
      assert_equal 18, @session.input_tokens  # 15 + 3
      assert_equal 42, @session.output_tokens # 35 + 7
    end

    def test_model_token_usage_with_no_tokens
      # Message with model but no token usage
      message = Messages::TextMessage.new({
        "type" => "assistant",
        "message" => {
          "content" => [{ "type" => "text", "text" => "Hello" }],
          "model" => "claude-opus"
        }
      })

      @session.send(:handle_message, message)

      # Should not create token tracking for this model
      assert_empty @session.model_token_usage
      assert_equal 0, @session.input_tokens
      assert_equal 0, @session.output_tokens
    end
  end
end