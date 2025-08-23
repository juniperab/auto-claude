# frozen_string_literal: true

require "test_helper"
require "auto_claude"
require "tempfile"

module AutoClaude
  class IntegrationTest < Minitest::Test
    def test_full_flow_with_memory_output
      output = AutoClaude::Output::Memory.new
      client = AutoClaude::Client.new(output: output)

      mock_claude_response = <<~JSON
        {"type": "assistant", "message": {"content": [{"type": "text", "text": "The answer is 4"}]}}
        {"type": "result", "subtype": "success", "result": "4", "success": true, "num_turns": 1, "duration_ms": 500, "total_cost_usd": 0.0001, "usage": {"input_tokens": 10, "output_tokens": 5}, "session_id": "test123"}
      JSON

      Open3.stub :popen3, create_mock_popen(mock_claude_response) do
        session = client.run("What is 2+2?")

        assert_predicate session, :success?
        assert_equal "4", session.result.content
        assert_in_delta(0.0001, session.cost)
        assert_equal 10, session.token_usage[:input]
        assert_equal 5, session.token_usage[:output]

        # Check output captured messages
        assert_equal 1, output.messages.count
        assert_equal "test123", output.stats["Session ID"] # Should show Claude's session ID
        assert_equal "test123", session.session_id # Should be accessible via method
        assert output.stats["Success"]
      end
    end

    def test_error_handling_flow
      output = AutoClaude::Output::Memory.new
      client = AutoClaude::Client.new(output: output)

      mock_error_response = <<~JSON
        {"type": "assistant", "message": {"content": [{"type": "text", "text": "Starting..."}]}}
        {"type": "result", "is_error": true, "result": "Rate limit exceeded"}
      JSON

      Open3.stub :popen3, create_mock_popen(mock_error_response) do
        session = client.run("Test error")

        refute_predicate session, :success?
        assert_predicate session, :error?
        assert_equal "Rate limit exceeded", session.result.error_message

        # Check error was captured
        assert_equal 1, output.messages.count
        refute output.stats["Success"]
      end
    end

    def test_concurrent_sessions
      output = AutoClaude::Output::Memory.new
      client = AutoClaude::Client.new(output: output)

      mock_responses = (1..3).map do |i|
        <<~JSON
          {"type": "assistant", "message": {"content": [{"type": "text", "text": "Response #{i}"}]}}
          {"type": "result", "subtype": "success", "result": "Result #{i}", "success": true, "session_id": "session#{i}"}
        JSON
      end

      response_index = 0
      Open3.stub :popen3, lambda { |script_path, &block|
        response = mock_responses[response_index]
        response_index += 1
        create_mock_popen(response).call(script_path, &block)
      } do
        threads = 3.times.map do |i|
          Thread.new { client.run("Prompt #{i}") }
        end

        sessions = threads.map(&:value)

        assert_equal 3, sessions.count
        sessions.each_with_index do |session, _i|
          assert_predicate session, :success?
          assert_match(/Result \d/, session.result.content)
        end
      end
    end

    def test_with_file_logging
      Tempfile.create("v2_test_log") do |tmpfile|
        file_output = AutoClaude::Output::File.new(tmpfile.path)
        terminal_output = AutoClaude::Output::Memory.new
        multiplexer = AutoClaude::Output::Multiplexer.new([terminal_output, file_output])

        client = AutoClaude::Client.new(output: multiplexer)

        mock_response = <<~JSON
          {"type": "assistant", "message": {"content": [{"type": "text", "text": "Logged response"}]}}
          {"type": "result", "subtype": "success", "result": "Done", "success": true}
        JSON

        Open3.stub :popen3, create_mock_popen(mock_response) do
          session = client.run("Test logging")
          file_output.write_metadata(session.metadata)
          file_output.close
        end

        log_content = File.read(tmpfile.path)

        assert_match(/Logged response/, log_content)
        assert_match(/Success: true/, log_content)  # Success stat, not result content
        assert_match(/"success":true/, log_content) # JSON metadata
      end
    end

    def test_callback_system
      client = AutoClaude::Client.new(output: AutoClaude::Output::Memory.new)

      messages_seen = []

      mock_response = <<~JSON
        {"type": "assistant", "message": {"content": [{"type": "text", "text": "First"}]}}
        {"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Bash", "input": {"command": "ls"}}]}}
        {"type": "user", "message": {"content": [{"type": "tool_result", "content": "files"}]}}
        {"type": "result", "subtype": "success", "result": "Complete"}
      JSON

      Open3.stub :popen3, create_mock_popen(mock_response) do
        client.run("Test callbacks") do |message|
          messages_seen << message.class.name.split("::").last
        end

        assert_equal %w[TextMessage ToolUseMessage ToolResultMessage ResultMessage], messages_seen
      end
    end

    def test_module_convenience_method
      mock_response = <<~JSON
        {"type": "result", "subtype": "success", "result": "Quick result"}
      JSON

      Open3.stub :popen3, create_mock_popen(mock_response) do
        result = AutoClaude.run("Quick test", output: AutoClaude::Output::Memory.new)

        assert_equal "Quick result", result
      end
    end

    private

    def create_mock_popen(stdout_content, exit_code = 0, stderr_content = "")
      lambda { |script_path, &block|
        # Verify script was created
        assert_path_exists script_path if script_path.is_a?(String)

        stdin = StringIO.new
        stdout = StringIO.new(stdout_content)
        stderr = StringIO.new(stderr_content)

        wait_thread = Minitest::Mock.new
        status = Process::Status.allocate
        status.instance_variable_set(:@exitstatus, exit_code)
        status.define_singleton_method(:success?) { exit_code.zero? }
        status.define_singleton_method(:exitstatus) { @exitstatus }
        wait_thread.expect :value, status

        block.call(stdin, stdout, stderr, wait_thread)
      }
    end
  end
end
