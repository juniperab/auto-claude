# frozen_string_literal: true

require "test_helper"
require "auto_claude"
require "tempfile"

module AutoClaude
  class AppIntegrationTest < Minitest::Test
    # Test the App.run backward compatibility interface

    def test_basic_app_run
      mock_response = <<~JSON
        {"type": "assistant", "message": {"content": [{"type": "text", "text": "Hello from Claude"}]}}
        {"type": "result", "subtype": "success", "result": "Task completed", "success": true, "session_id": "app-test-123"}
      JSON

      Open3.stub :popen3, create_mock_popen(mock_response) do
        result = AutoClaude::App.run("Test prompt")

        assert_equal "Task completed", result
      end
    end

    def test_app_run_with_directory
      Dir.mktmpdir do |tmpdir|
        mock_response = <<~JSON
          {"type": "result", "subtype": "success", "result": "Directory test passed"}
        JSON

        script_content = nil

        Open3.stub :popen3, lambda { |script_path, &block|
          # Capture the script to verify directory
          script_content = File.read(script_path) if File.exist?(script_path)
          create_mock_popen(mock_response).call(script_path, &block)
        } do
          result = AutoClaude::App.run(
            "Test in directory",
            directory: tmpdir
          )

          assert_equal "Directory test passed", result
          assert_match(/cd.*#{Regexp.escape(tmpdir)}/, script_content)
        end
      end
    end

    def test_app_run_with_claude_options
      mock_response = <<~JSON
        {"type": "result", "subtype": "success", "result": "Options test"}
      JSON

      script_content = nil

      Open3.stub :popen3, lambda { |script_path, &block|
        script_content = File.read(script_path) if File.exist?(script_path)
        create_mock_popen(mock_response).call(script_path, &block)
      } do
        result = AutoClaude::App.run(
          "Test with options",
          claude_options: ["--model", "opus", "--temperature", "0.7"]
        )

        assert_equal "Options test", result
        assert_match(/--model.*opus/, script_content)
        assert_match(/--temperature.*0\.7/, script_content)
      end
    end

    def test_app_run_with_log_file
      Tempfile.create("app_test_log") do |tmpfile|
        mock_response = <<~JSON
          {"type": "assistant", "message": {"content": [{"type": "text", "text": "Logged message"}]}}
          {"type": "result", "subtype": "success", "result": "Log test done", "session_id": "log-123"}
        JSON

        Open3.stub :popen3, create_mock_popen(mock_response) do
          result = AutoClaude::App.run(
            "Test logging",
            log_file: tmpfile.path
          )

          assert_equal "Log test done", result
        end

        # Check log file was written
        log_content = File.read(tmpfile.path)

        assert_match(/Logged message/, log_content)
        assert_match(/Session ID: log-123/, log_content)
      end
    end

    def test_app_run_error_handling
      mock_response = <<~JSON
        {"type": "result", "is_error": true, "result": "API error occurred"}
      JSON

      Open3.stub :popen3, create_mock_popen(mock_response) do
        # App.run raises errors on failure
        assert_raises(RuntimeError) do
          AutoClaude::App.run("Test error")
        end
      end
    end

    def test_app_run_with_retry
      # First attempt fails, second succeeds
      first_response = <<~JSON
        {"type": "result", "is_error": true, "result": "First attempt failed", "session_id": "fail-123"}
      JSON

      second_response = <<~JSON
        {"type": "result", "subtype": "success", "result": "Retry succeeded", "session_id": "success-456"}
      JSON

      responses = [first_response, second_response]
      call_count = 0

      Open3.stub :popen3, lambda { |script_path, &block|
        response = responses[call_count]
        call_count += 1
        create_mock_popen(response).call(script_path, &block)
      } do
        result = AutoClaude::App.run(
          "Test retry",
          retry_on_error: true
        )

        assert_equal "Retry succeeded", result
        assert_equal 2, call_count
      end
    end

    # Test the module-level convenience method
    def test_module_run_method
      mock_response = <<~JSON
        {"type": "assistant", "message": {"content": [{"type": "text", "text": "Module method"}]}}
        {"type": "result", "subtype": "success", "result": "Module result"}
      JSON

      Open3.stub :popen3, create_mock_popen(mock_response) do
        result = AutoClaude.run("Test module method")

        assert_equal "Module result", result
      end
    end

    def test_module_run_with_options
      mock_response = <<~JSON
        {"type": "result", "subtype": "success", "result": "Module with options"}
      JSON

      script_content = nil

      Open3.stub :popen3, lambda { |script_path, &block|
        script_content = File.read(script_path) if File.exist?(script_path)
        create_mock_popen(mock_response).call(script_path, &block)
      } do
        result = AutoClaude.run(
          "Test module options",
          claude_options: ["--model", "sonnet"]
        )

        assert_equal "Module with options", result
        assert_match(/--model.*sonnet/, script_content)
      end
    end

    # Test Client.new with different configurations
    def test_client_with_custom_directory
      Dir.mktmpdir do |tmpdir|
        client = AutoClaude::Client.new(directory: tmpdir)

        mock_response = <<~JSON
          {"type": "result", "subtype": "success", "result": "Client dir test"}
        JSON

        script_content = nil

        Open3.stub :popen3, lambda { |script_path, &block|
          script_content = File.read(script_path) if File.exist?(script_path)
          create_mock_popen(mock_response).call(script_path, &block)
        } do
          session = client.run("Test prompt")

          assert_predicate session, :success?
          assert_equal "Client dir test", session.result.content
          assert_match(/cd.*#{Regexp.escape(tmpdir)}/, script_content)
        end
      end
    end

    def test_client_with_memory_output
      output = AutoClaude::Output::Memory.new
      client = AutoClaude::Client.new(output: output)

      mock_response = <<~JSON
        {"type": "assistant", "message": {"content": [{"type": "text", "text": "Memory test"}]}}
        {"type": "result", "subtype": "success", "result": "Memory result", "session_id": "mem-123"}
      JSON

      Open3.stub :popen3, create_mock_popen(mock_response) do
        session = client.run("Test memory")

        assert_predicate session, :success?
        assert_equal "Memory result", session.result.content
        assert_equal "mem-123", session.session_id

        # Check memory output captured everything
        assert_equal 1, output.messages.count
        assert_equal "mem-123", output.stats["Session ID"]
        assert output.stats["Success"]
      end
    end

    def test_client_run_async
      client = AutoClaude::Client.new(output: AutoClaude::Output::Memory.new)

      mock_response = <<~JSON
        {"type": "result", "subtype": "success", "result": "Async result"}
      JSON

      Open3.stub :popen3, create_mock_popen(mock_response) do
        thread = client.run_async("Test async")

        assert_kind_of Thread, thread
        session = thread.value

        assert_predicate session, :success?
        assert_equal "Async result", session.result.content
      end
    end

    def test_client_with_callbacks
      client = AutoClaude::Client.new(output: AutoClaude::Output::Memory.new)

      messages_received = []

      mock_response = <<~JSON
        {"type": "assistant", "message": {"content": [{"type": "text", "text": "Step 1"}]}}
        {"type": "assistant", "message": {"content": [{"type": "text", "text": "Step 2"}]}}
        {"type": "result", "subtype": "success", "result": "Callback test done"}
      JSON

      Open3.stub :popen3, create_mock_popen(mock_response) do
        session = client.run("Test callbacks") do |message|
          messages_received << message
        end

        assert_predicate session, :success?
        assert_equal 3, messages_received.count
        assert_equal "Step 1", messages_received[0].text
        assert_equal "Step 2", messages_received[1].text
        assert_equal "Callback test done", messages_received[2].content
      end
    end

    def test_multiple_sessions_on_same_client
      client = AutoClaude::Client.new(output: AutoClaude::Output::Memory.new)

      responses = (1..3).map do |i|
        <<~JSON
          {"type": "result", "subtype": "success", "result": "Result #{i}", "session_id": "session-#{i}"}
        JSON
      end

      response_index = 0

      Open3.stub :popen3, lambda { |script_path, &block|
        response = responses[response_index]
        response_index += 1
        create_mock_popen(response).call(script_path, &block)
      } do
        # Run multiple sessions sequentially
        session1 = client.run("Prompt 1")
        session2 = client.run("Prompt 2")
        session3 = client.run("Prompt 3")

        assert_equal 3, client.sessions.count
        assert_equal "Result 1", session1.result.content
        assert_equal "Result 2", session2.result.content
        assert_equal "Result 3", session3.result.content

        assert_equal "session-1", session1.session_id
        assert_equal "session-2", session2.session_id
        assert_equal "session-3", session3.session_id
      end
    end

    def test_session_metadata_access
      client = AutoClaude::Client.new(output: AutoClaude::Output::Memory.new)

      mock_response = <<~JSON
        {"type": "assistant", "message": {"content": [{"type": "text", "text": "Test"}]}}
        {"type": "result", "subtype": "success", "result": "Done", "success": true, "num_turns": 3, "duration_ms": 1500, "total_cost_usd": 0.002, "usage": {"input_tokens": 100, "output_tokens": 50}, "session_id": "meta-123"}
      JSON

      Open3.stub :popen3, create_mock_popen(mock_response) do
        session = client.run("Test metadata")

        # Debug: Check what messages were received
        assert_equal 2, session.messages.count, "Should have received 2 messages (text + result)"

        # Ensure result is set
        refute_nil session.result, "Session result should not be nil"
        assert_predicate session, :success?
        refute_predicate session, :error?

        # Check all metadata accessors
        assert_equal "meta-123", session.session_id
        assert_in_delta(0.002, session.cost)
        assert_equal({ input: 100, output: 50 }, session.token_usage)
        assert_equal 3, session.metadata["num_turns"]
        assert_equal 1500, session.metadata["duration_ms"]

        # Duration should be calculated based on actual time
        assert_operator session.duration, :>, 0
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
