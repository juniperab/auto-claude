# frozen_string_literal: true

require "test_helper"
require "auto_claude"

module AutoClaude
  class RetryResumeTest < Minitest::Test
    def test_retry_with_resume_on_failure
      output = AutoClaude::Output::Memory.new

      # First attempt fails with a session ID
      first_response = <<~JSON
        {"type": "assistant", "message": {"content": [{"type": "text", "text": "Starting..."}]}}
        {"type": "result", "is_error": true, "result": "Network error", "session_id": "session-123"}
      JSON

      # Second attempt succeeds with different session ID (showing resume worked)
      second_response = <<~JSON
        {"type": "assistant", "message": {"content": [{"type": "text", "text": "Resumed and completed"}]}}
        {"type": "result", "subtype": "success", "result": "Done", "success": true, "session_id": "session-456"}
      JSON

      # Third response won't be needed since second succeeds
      third_response = <<~JSON
        {"type": "result", "subtype": "success", "result": "Not reached", "session_id": "session-789"}
      JSON

      responses = [first_response, second_response, third_response]
      call_count = 0
      claude_options_captured = []

      Open3.stub :popen3, lambda { |script_path, &block|
        # Capture the claude options from the script
        if File.exist?(script_path)
          script_content = File.read(script_path)
          # Extract command from script (it's in the exec line)
          if script_content =~ /exec (.+)/
            command = ::Regexp.last_match(1)
            # Parse out the claude options
            parts = command.shellsplit
            claude_idx = parts.index("claude")
            if claude_idx
              options = parts[(claude_idx + 1)..]
              claude_options_captured << options
            end
          end
        end

        response = responses[call_count]
        call_count += 1
        create_mock_popen(response).call(script_path, &block)
      } do
        # Test with App.run (backward compatibility)
        result = AutoClaude::App.run(
          "Test prompt",
          output: output,
          retry_on_error: true
        )

        assert_equal "Done", result
        assert_equal 2, call_count # Should stop after success on second attempt

        # Check that the second call included --resume with the session ID from the first failure
        assert_equal 2, claude_options_captured.length
        first_options = claude_options_captured[0]
        second_options = claude_options_captured[1]

        # First call should not have --resume (unless we passed it initially)
        refute_includes first_options, "--resume"

        # Second call should have --resume with the session ID from the first failure
        assert_includes second_options, "--resume"
        resume_idx = second_options.index("--resume")

        assert_equal "session-123", second_options[resume_idx + 1]
      end
    end

    def test_retry_overrides_existing_resume
      output = AutoClaude::Output::Memory.new

      # First attempt fails with a session ID
      first_response = <<~JSON
        {"type": "result", "is_error": true, "result": "Failed", "session_id": "new-session-789"}
      JSON

      # Second attempt succeeds
      second_response = <<~JSON
        {"type": "result", "subtype": "success", "result": "Success", "session_id": "final-session"}
      JSON

      responses = [first_response, second_response]
      call_count = 0
      claude_options_captured = []

      Open3.stub :popen3, lambda { |script_path, &block|
        # Capture the claude options
        if File.exist?(script_path)
          script_content = File.read(script_path)
          if script_content =~ /exec (.+)/
            command = ::Regexp.last_match(1)
            parts = command.shellsplit
            claude_idx = parts.index("claude")
            if claude_idx
              options = parts[(claude_idx + 1)..]
              claude_options_captured << options
            end
          end
        end

        response = responses[call_count]
        call_count += 1
        create_mock_popen(response).call(script_path, &block)
      } do
        # Start with an existing --resume flag
        result = AutoClaude::App.run(
          "Test prompt",
          output: output,
          claude_options: ["--resume", "old-session-456", "--model", "opus"],
          retry_on_error: true
        )

        assert_equal "Success", result
        assert_equal 2, call_count

        # Check the options
        first_options = claude_options_captured[0]
        second_options = claude_options_captured[1]

        # First call should have the original resume
        resume_idx = first_options.index("--resume")

        assert_equal "old-session-456", first_options[resume_idx + 1]
        assert_includes first_options, "--model"

        # Second call should have replaced the resume with the new session ID
        resume_idx = second_options.index("--resume")

        assert_equal "new-session-789", second_options[resume_idx + 1]
        assert_includes second_options, "--model" # Other options preserved

        # Make sure there's only one --resume in the second call
        assert_equal 1, second_options.count("--resume")
      end
    end

    def test_no_retry_without_flag
      output = AutoClaude::Output::Memory.new

      # Single failing response
      response = <<~JSON
        {"type": "result", "is_error": true, "result": "Failed", "session_id": "session-999"}
      JSON

      call_count = 0

      Open3.stub :popen3, lambda { |script_path, &block|
        call_count += 1
        create_mock_popen(response).call(script_path, &block)
      } do
        # Without retry_on_error, should fail immediately
        assert_raises(RuntimeError) do
          AutoClaude::App.run(
            "Test prompt",
            output: output,
            retry_on_error: false # No retry
          )
        end

        # Should have only tried once
        assert_equal 1, call_count
      end
    end

    def test_retry_without_session_id_in_first_failure
      output = AutoClaude::Output::Memory.new

      # First attempt fails WITHOUT a session ID
      first_response = <<~JSON
        {"type": "result", "is_error": true, "result": "Connection failed"}
      JSON

      # Second attempt succeeds
      second_response = <<~JSON
        {"type": "result", "subtype": "success", "result": "Success", "session_id": "new-session"}
      JSON

      # Third response won't be needed
      third_response = <<~JSON
        {"type": "result", "subtype": "success", "result": "Not reached"}
      JSON

      responses = [first_response, second_response, third_response]
      call_count = 0
      claude_options_captured = []

      Open3.stub :popen3, lambda { |script_path, &block|
        # Capture the claude options
        if File.exist?(script_path)
          script_content = File.read(script_path)
          if script_content =~ /exec (.+)/
            command = ::Regexp.last_match(1)
            parts = command.shellsplit
            claude_idx = parts.index("claude")
            if claude_idx
              options = parts[(claude_idx + 1)..]
              claude_options_captured << options
            end
          end
        end

        response = responses[call_count]
        call_count += 1
        create_mock_popen(response).call(script_path, &block)
      } do
        result = AutoClaude::App.run(
          "Test prompt",
          output: output,
          retry_on_error: true
        )

        assert_equal "Success", result
        assert_equal 2, call_count # Should stop after success on second attempt

        # Second call should NOT have --resume since first failure had no session ID
        second_options = claude_options_captured[1]

        refute_includes second_options, "--resume"
      end
    end

    def test_successful_first_attempt_no_retry
      output = AutoClaude::Output::Memory.new

      # First attempt succeeds
      response = <<~JSON
        {"type": "result", "subtype": "success", "result": "Success immediately", "session_id": "session-1"}
      JSON

      call_count = 0

      Open3.stub :popen3, lambda { |script_path, &block|
        call_count += 1
        create_mock_popen(response).call(script_path, &block)
      } do
        result = AutoClaude::App.run(
          "Test prompt",
          output: output,
          retry_on_error: true
        )

        assert_equal "Success immediately", result
        # Should only have tried once since it succeeded
        assert_equal 1, call_count
      end
    end

    def test_three_attempts_with_two_retries
      output = AutoClaude::Output::Memory.new

      # First two attempts fail, third succeeds
      first_response = <<~JSON
        {"type": "result", "is_error": true, "result": "Failed 1", "session_id": "session-1"}
      JSON

      second_response = <<~JSON
        {"type": "result", "is_error": true, "result": "Failed 2", "session_id": "session-2"}
      JSON

      third_response = <<~JSON
        {"type": "result", "subtype": "success", "result": "Finally worked", "session_id": "session-3"}
      JSON

      responses = [first_response, second_response, third_response]
      call_count = 0
      claude_options_captured = []

      Open3.stub :popen3, lambda { |script_path, &block|
        # Capture the claude options
        if File.exist?(script_path)
          script_content = File.read(script_path)
          if script_content =~ /exec (.+)/
            command = ::Regexp.last_match(1)
            parts = command.shellsplit
            claude_idx = parts.index("claude")
            if claude_idx
              options = parts[(claude_idx + 1)..]
              claude_options_captured << options
            end
          end
        end

        response = responses[call_count]
        call_count += 1
        create_mock_popen(response).call(script_path, &block)
      } do
        result = AutoClaude::App.run(
          "Test prompt",
          output: output,
          retry_on_error: true
        )

        assert_equal "Finally worked", result
        assert_equal 3, call_count # Should have tried 3 times total

        # Check the resume chain
        first_options = claude_options_captured[0]
        second_options = claude_options_captured[1]
        third_options = claude_options_captured[2]

        # First call should not have --resume
        refute_includes first_options, "--resume"

        # Second call should resume from first failure
        resume_idx = second_options.index("--resume")

        assert_equal "session-1", second_options[resume_idx + 1]

        # Third call should resume from second failure
        resume_idx = third_options.index("--resume")

        assert_equal "session-2", third_options[resume_idx + 1]
      end
    end

    def test_all_three_attempts_fail
      output = AutoClaude::Output::Memory.new

      # All three attempts fail
      responses = (1..3).map do |i|
        <<~JSON
          {"type": "result", "is_error": true, "result": "Failed #{i}", "session_id": "session-#{i}"}
        JSON
      end

      call_count = 0

      Open3.stub :popen3, lambda { |script_path, &block|
        response = responses[call_count]
        call_count += 1
        create_mock_popen(response).call(script_path, &block)
      } do
        # Should fail after 3 attempts
        assert_raises(RuntimeError) do
          AutoClaude::App.run(
            "Test prompt",
            output: output,
            retry_on_error: true
          )
        end

        # Should have tried exactly 3 times
        assert_equal 3, call_count
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
        status = ::Process::Status.allocate
        status.instance_variable_set(:@exitstatus, exit_code)
        status.define_singleton_method(:success?) { exit_code.zero? }
        status.define_singleton_method(:exitstatus) { @exitstatus }
        wait_thread.expect :value, status

        block.call(stdin, stdout, stderr, wait_thread)
      }
    end
  end
end
