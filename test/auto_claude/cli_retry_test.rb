# frozen_string_literal: true

require "test_helper"
require "auto_claude/cli"
require "auto_claude/output/memory"

module AutoClaude
  class CliRetryTest < Minitest::Test
    def setup
      @memory_output = Output::Memory.new
    end

    def test_retry_uses_session_id_from_crashed_session
      # Create a mock client that will capture session_id then crash
      mock_client = Minitest::Mock.new
      
      # Create a session that captured session_id before crashing
      crashed_session = Session.new(
        directory: Dir.pwd,
        output: @memory_output,
        claude_options: []
      )
      
      # Simulate that the session captured a session_id from early messages
      crashed_session.instance_variable_set(:@metadata, { "session_id" => "crash-session-123" })
      
      # The client's sessions array should contain the crashed session
      mock_client.expect :sessions, [crashed_session]
      mock_client.expect :run, nil do |_prompt|
        raise StandardError, "Claude process crashed"
      end

      # For the retry attempt, expect resume with the captured session_id
      mock_retry_client = Minitest::Mock.new
      success_session = Session.new(
        directory: Dir.pwd,
        output: @memory_output,
        claude_options: []
      )
      success_session.instance_variable_set(:@result, 
        Messages::ResultMessage.new({
          "type" => "result",
          "subtype" => "success",
          "result" => "Recovered",
          "success" => true
        })
      )
      mock_retry_client.expect :run, success_session, [String]

      # Test the retry flow
      options = {
        retry_on_error: true,
        claude_options: []
      }

      # Mock Client.new to return our mock clients
      Client.stub :new, ->(opts) {
        # Check if resume options are being used
        if opts[:claude_options].include?("--resume")
          assert_includes opts[:claude_options], "crash-session-123"
          mock_retry_client
        else
          mock_client
        end
      } do
        # Capture warnings to verify retry message
        warnings = []
        CLI.stub :warn, ->(msg) { warnings << msg } do
          session = CLI.run_with_retry("test prompt", options, @memory_output)
          
          assert session.success?
          assert_includes warnings.join("\n"), "crash-session-123"
        end
      end

      mock_client.verify
      mock_retry_client.verify
    end

    def test_retry_without_session_id_on_early_crash
      # Create a mock client that crashes immediately without session_id
      mock_client = Minitest::Mock.new
      mock_client.expect :sessions, []  # No sessions captured
      mock_client.expect :run, nil do |_prompt|
        raise StandardError, "Immediate crash"
      end

      # For retry, no session_id available
      mock_retry_client = Minitest::Mock.new
      success_session = Session.new(
        directory: Dir.pwd,
        output: @memory_output,
        claude_options: []
      )
      success_session.instance_variable_set(:@result,
        Messages::ResultMessage.new({
          "type" => "result",
          "subtype" => "success",
          "result" => "Success without resume",
          "success" => true
        })
      )
      mock_retry_client.expect :run, success_session, [String]

      options = {
        retry_on_error: true,
        claude_options: []
      }

      Client.stub :new, ->(opts) {
        # Should NOT have resume options on retry since no session_id
        refute_includes opts[:claude_options], "--resume"
        
        if @first_call
          mock_retry_client
        else
          @first_call = true
          mock_client
        end
      } do
        warnings = []
        CLI.stub :warn, ->(msg) { warnings << msg } do
          session = CLI.run_with_retry("test prompt", options, @memory_output)
          
          assert session.success?
          # Should have error message but not session_id message
          assert_match(/Immediate crash/, warnings.join("\n"))
          refute_match(/Will retry with session ID/, warnings.join("\n"))
        end
      end

      mock_client.verify
      mock_retry_client.verify
    end

    def test_session_id_updates_during_execution_before_crash
      # Simulate a session that receives multiple messages with changing session_ids
      session = Session.new(
        directory: Dir.pwd,
        output: @memory_output,
        claude_options: []
      )

      # First message with initial session_id
      message1 = Messages::SystemMessage.new({
        "type" => "system",
        "message" => "init",
        "session_id" => "initial-session"
      })
      session.send(:handle_message, message1)
      assert_equal "initial-session", session.session_id

      # Second message with updated session_id
      message2 = Messages::TextMessage.new({
        "type" => "assistant",
        "message" => { "content" => [{ "type" => "text", "text" => "Processing" }] },
        "session_id" => "updated-session"
      })
      session.send(:handle_message, message2)
      assert_equal "updated-session", session.session_id

      # Simulate crash - session should still have the latest session_id
      assert_equal "updated-session", session.session_id
    end

    def test_no_retry_when_option_not_set
      mock_client = Minitest::Mock.new
      mock_client.expect :sessions, []  # Expect sessions call
      mock_client.expect :run, nil do |_prompt|
        raise StandardError, "Error without retry"
      end

      options = {
        retry_on_error: false,
        claude_options: []
      }

      Client.stub :new, mock_client do
        assert_raises(SystemExit) do
          CLI.stub :warn, ->(_msg) {} do
            CLI.run_with_retry("test prompt", options, @memory_output)
          end
        end
      end

      mock_client.verify
    end
  end
end