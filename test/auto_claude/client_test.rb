# frozen_string_literal: true

require "test_helper"
require "auto_claude"

module AutoClaude
  class ClientTest < Minitest::Test
    def setup
      @memory_output = AutoClaude::Output::Memory.new
    end

    def test_initialize_with_defaults
      client = AutoClaude::Client.new

      assert_equal Dir.pwd, client.instance_variable_get(:@directory)
      assert_kind_of AutoClaude::Output::Terminal, client.instance_variable_get(:@output)
      assert_empty client.sessions
    end

    def test_initialize_with_custom_directory
      Dir.mktmpdir do |tmpdir|
        client = AutoClaude::Client.new(directory: tmpdir)

        assert_equal tmpdir, client.instance_variable_get(:@directory)
      end
    end

    def test_initialize_with_invalid_directory
      assert_raises(ArgumentError) do
        AutoClaude::Client.new(directory: "/nonexistent/path")
      end
    end

    def test_initialize_with_custom_output
      client = AutoClaude::Client.new(output: @memory_output)

      assert_equal @memory_output, client.instance_variable_get(:@output)
    end

    def test_run_with_real_process_manager
      client = AutoClaude::Client.new(output: @memory_output)

      mock_response = <<~JSON
        {"type": "assistant", "message": {"content": [{"type": "text", "text": "Hello"}]}}
        {"type": "result", "subtype": "success", "result": "Done", "success": true}
      JSON

      # Mock at the Open3 level, allowing real Process::Manager to work
      Open3.stub :popen3, create_mock_popen(mock_response) do
        session = client.run("test prompt")

        # Verify real business logic executed
        assert_kind_of AutoClaude::Session, session
        assert_includes client.sessions, session
        assert_equal 1, client.sessions.count

        # Verify session has expected data
        assert_predicate session, :success?
        assert_equal "Done", session.result.content
        
        # Verify output received messages
        assert_equal 1, @memory_output.messages.count
        assert_equal "Hello", @memory_output.messages.first.text
      end
    end

    def test_run_with_block_callback
      client = AutoClaude::Client.new(output: @memory_output)
      messages_received = []

      mock_response = <<~JSON
        {"type": "assistant", "message": {"content": [{"type": "text", "text": "Step 1"}]}}
        {"type": "assistant", "message": {"content": [{"type": "text", "text": "Step 2"}]}}
        {"type": "result", "subtype": "success", "result": "Complete", "success": true}
      JSON

      Open3.stub :popen3, create_mock_popen(mock_response) do
        session = client.run("test") do |message|
          messages_received << message
        end

        # Verify callbacks were invoked with real messages
        assert_equal 3, messages_received.count
        assert_equal "Step 1", messages_received[0].text
        assert_equal "Step 2", messages_received[1].text
        assert_equal "Complete", messages_received[2].content
        
        # Verify session completed successfully
        assert_predicate session, :success?
      end
    end

    def test_run_async_with_real_execution
      client = AutoClaude::Client.new(output: @memory_output)

      mock_response = <<~JSON
        {"type": "assistant", "message": {"content": [{"type": "text", "text": "Async response"}]}}
        {"type": "result", "subtype": "success", "result": "Async done", "success": true}
      JSON

      Open3.stub :popen3, create_mock_popen(mock_response) do
        thread = client.run_async("test prompt")

        assert_kind_of Thread, thread
        
        # Wait for async execution
        session = thread.value

        # Verify async execution completed with real data
        assert_kind_of AutoClaude::Session, session
        assert_predicate session, :success?
        assert_equal "Async done", session.result.content
        
        # Verify output received messages asynchronously
        assert_equal 1, @memory_output.messages.count
      end
    end

    def test_multiple_concurrent_sessions_with_real_execution
      client = AutoClaude::Client.new(output: @memory_output)

      # Create a single response that all sessions will get
      # (in real usage, each would get different Claude responses)
      mock_response = <<~JSON
        {"type": "assistant", "message": {"content": [{"type": "text", "text": "Concurrent response"}]}}
        {"type": "result", "subtype": "success", "result": "Concurrent result", "success": true, "session_id": "concurrent-session"}
      JSON
      
      Open3.stub :popen3, create_mock_popen(mock_response) do
        threads = 5.times.map do |i|
          client.run_async("prompt #{i}")
        end

        sessions = threads.map(&:value)

        # Verify all sessions completed
        assert_equal 5, sessions.count
        assert_equal 5, client.sessions.count
        
        # Verify each session completed successfully
        sessions.each do |session|
          assert_predicate session, :success?
          assert_equal "Concurrent result", session.result.content
          assert_equal "concurrent-session", session.session_id
        end
        
        # Verify all messages were captured
        assert_equal 5, @memory_output.messages.count
      end
    end

    def test_error_handling_with_real_process_manager
      client = AutoClaude::Client.new(output: @memory_output)

      # Test process failure (non-zero exit code)
      Open3.stub :popen3, create_mock_popen("", 1, "Command failed") do
        error = assert_raises(RuntimeError) do
          client.run("test error")
        end

        assert_match(/exit code 1/, error.message)
        assert_match(/Command failed/, error.message)
        
        # Verify no session was added on error
        assert_empty client.sessions
      end
    end

    def test_session_with_metadata
      client = AutoClaude::Client.new(output: @memory_output)

      mock_response = <<~JSON
        {"type": "assistant", "message": {"content": [{"type": "text", "text": "Processing"}]}}
        {"type": "result", "subtype": "success", "result": "Done", "success": true, "num_turns": 2, "duration_ms": 1000, "total_cost_usd": 0.002, "usage": {"input_tokens": 100, "output_tokens": 50}, "session_id": "test-123"}
      JSON

      Open3.stub :popen3, create_mock_popen(mock_response) do
        session = client.run("test metadata")

        # Verify metadata is properly extracted
        assert_equal "test-123", session.session_id
        assert_in_delta(0.002, session.cost)
        assert_equal({ input: 100, output: 50 }, session.token_usage)
        assert_equal 2, session.metadata["num_turns"]
        assert_equal 1000, session.metadata["duration_ms"]
      end
    end

    private

    def create_mock_popen(stdout_content, exit_code = 0, stderr_content = "")
      lambda { |script_path, &block|
        # Verify script was created (real Process::Manager behavior)
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