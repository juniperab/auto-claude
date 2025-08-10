require "test_helper"
require "json"

class AutoClaude::IntegrationTest < Minitest::Test
  def setup
    @original_stderr = $stderr
    @original_stdout = $stdout
    @stderr_output = StringIO.new
    @stdout_output = StringIO.new
    $stderr = @stderr_output
    $stdout = @stdout_output
  end
  
  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout
    AutoClaude::ColorPrinter.stderr_callback = nil
    AutoClaude::ColorPrinter.close_log_file
  end

  # Helper to create mock Claude JSON stream
  def create_mock_stream(*messages)
    messages.map { |msg| msg.to_json + "\n" }.join
  end

  # Complete conversation flow tests

  def test_simple_question_answer_flow
    # Mock a simple Q&A interaction
    mock_output = create_mock_stream(
      {"type" => "assistant", "message" => {"content" => [
        {"type" => "text", "text" => "The answer is 4"}
      ]}},
      {"type" => "result", "subtype" => "success", "result" => "The answer is 4", 
       "success" => true, "num_turns" => 1, "duration_ms" => 500,
       "total_cost_usd" => 0.0001, "usage" => {"input_tokens" => 10, "output_tokens" => 5}}
    )
    
    Open3.stub :popen3, -> (*args, &block) {
      stdin = StringIO.new
      stdout = StringIO.new(mock_output)
      stderr = StringIO.new
      wait_thread = create_success_thread
      block.call(stdin, stdout, stderr, wait_thread)
    } do
      runner = AutoClaude::ClaudeRunner.new
      result = runner.run("What is 2+2?")
      
      assert_equal "The answer is 4", result
      assert_match(/The answer is 4/, @stderr_output.string)
      assert_match(/Success: true/, @stderr_output.string)
      assert_match(/Cost:/, @stderr_output.string)
    end
  end

  def test_tool_use_conversation_flow
    # Mock a conversation with tool use
    mock_output = create_mock_stream(
      {"type" => "assistant", "message" => {"content" => [
        {"type" => "text", "text" => "I'll help you with that. Let me check the files."}
      ]}},
      {"type" => "assistant", "message" => {"content" => [
        {"type" => "tool_use", "name" => "Bash", "input" => {"command" => "ls -la"}}
      ]}},
      {"type" => "user", "message" => {"content" => [
        {"type" => "tool_result", "content" => "file1.txt\nfile2.txt"}
      ]}},
      {"type" => "assistant", "message" => {"content" => [
        {"type" => "text", "text" => "I found 2 files: file1.txt and file2.txt"}
      ]}},
      {"type" => "result", "subtype" => "success", "result" => "Found 2 files",
       "success" => true, "num_turns" => 2}
    )
    
    Open3.stub :popen3, -> (*args, &block) {
      stdin = StringIO.new
      stdout = StringIO.new(mock_output)
      stderr = StringIO.new
      wait_thread = create_success_thread
      block.call(stdin, stdout, stderr, wait_thread)
    } do
      runner = AutoClaude::ClaudeRunner.new
      result = runner.run("List the files")
      
      assert_equal "Found 2 files", result
      
      output = @stderr_output.string
      assert_match(/I'll help you with that/, output)
      assert_match(/Bash\("ls -la"\)/, output)
      assert_match(/I found 2 files/, output)
      assert_match(/Turns: 2/, output)
    end
  end

  def test_multi_tool_use_flow
    # Mock multiple tool uses in sequence
    mock_output = create_mock_stream(
      {"type" => "assistant", "message" => {"content" => [
        {"type" => "tool_use", "name" => "Read", "input" => {"file_path" => "/tmp/test.txt"}}
      ]}},
      {"type" => "user", "message" => {"content" => [
        {"type" => "tool_result", "content" => "File contents here"}
      ]}},
      {"type" => "assistant", "message" => {"content" => [
        {"type" => "tool_use", "name" => "Edit", "input" => {
          "file_path" => "/tmp/test.txt", 
          "old_string" => "old", 
          "new_string" => "new"
        }}
      ]}},
      {"type" => "user", "message" => {"content" => [
        {"type" => "tool_result", "content" => "File updated"}
      ]}},
      {"type" => "assistant", "message" => {"content" => [
        {"type" => "text", "text" => "File has been updated successfully"}
      ]}},
      {"type" => "result", "subtype" => "success", "result" => "Done", "success" => true}
    )
    
    Open3.stub :popen3, -> (*args, &block) {
      stdin = StringIO.new
      stdout = StringIO.new(mock_output)
      stderr = StringIO.new
      wait_thread = create_success_thread
      block.call(stdin, stdout, stderr, wait_thread)
    } do
      runner = AutoClaude::ClaudeRunner.new
      result = runner.run("Update the file")
      
      assert_equal "Done", result
      
      output = @stderr_output.string
      assert_match(/Read\("\/tmp\/test.txt"\)/, output)
      assert_match(/Edit\("\/tmp\/test.txt"\)/, output)
      assert_match(/File has been updated successfully/, output)
    end
  end

  def test_todo_write_flow
    # Mock TodoWrite tool use
    mock_output = create_mock_stream(
      {"type" => "assistant", "message" => {"content" => [
        {"type" => "text", "text" => "I'll create a todo list for this task"}
      ]}},
      {"type" => "assistant", "message" => {"content" => [
        {"type" => "tool_use", "name" => "TodoWrite", "input" => {
          "todos" => [
            {"id" => "1", "content" => "Research the topic", "status" => "completed"},
            {"id" => "2", "content" => "Write the code", "status" => "in_progress"},
            {"id" => "3", "content" => "Test the implementation", "status" => "pending"}
          ]
        }}
      ]}},
      {"type" => "result", "subtype" => "success", "result" => "Todo list created", "success" => true}
    )
    
    Open3.stub :popen3, -> (*args, &block) {
      stdin = StringIO.new
      stdout = StringIO.new(mock_output)
      stderr = StringIO.new
      wait_thread = create_success_thread
      block.call(stdin, stdout, stderr, wait_thread)
    } do
      runner = AutoClaude::ClaudeRunner.new
      result = runner.run("Create a todo list")
      
      assert_equal "Todo list created", result
      
      output = @stderr_output.string
      assert_match(/TodoWrite/, output)
      assert_match(/\[x\] Research the topic/, output)
      assert_match(/\[-\] Write the code/, output)
      assert_match(/\[ \] Test the implementation/, output)
    end
  end

  # Error handling flow tests

  def test_error_result_flow
    mock_output = create_mock_stream(
      {"type" => "assistant", "message" => {"content" => [
        {"type" => "text", "text" => "Starting task..."}
      ]}},
      {"type" => "result", "is_error" => true, "result" => "Rate limit exceeded", "error" => {"message" => "Rate limit exceeded"}}
    )
    
    Open3.stub :popen3, -> (*args, &block) {
      stdin = StringIO.new
      stdout = StringIO.new(mock_output)
      stderr = StringIO.new
      wait_thread = create_success_thread
      block.call(stdin, stdout, stderr, wait_thread)
    } do
      runner = AutoClaude::ClaudeRunner.new
      
      # The run method should raise an error
      error = assert_raises(RuntimeError) do
        runner.run("Do something")
      end
      
      assert_match(/Rate limit exceeded/, error.message)
    end
  end

  def test_process_failure_flow
    mock_output = create_mock_stream(
      {"type" => "assistant", "message" => {"content" => [
        {"type" => "text", "text" => "Processing..."}
      ]}}
      # No result message - simulating incomplete stream
    )
    
    Open3.stub :popen3, -> (*args, &block) {
      stdin = StringIO.new
      stdout = StringIO.new(mock_output)
      stderr = StringIO.new("Claude process crashed")
      wait_thread = create_failure_thread(1)
      block.call(stdin, stdout, stderr, wait_thread)
    } do
      runner = AutoClaude::ClaudeRunner.new
      
      # The run method should raise an error
      error = assert_raises(RuntimeError) do
        runner.run("Do something")
      end
      
      assert_match(/exit code 1/, error.message)
      assert_match(/Claude process crashed/, error.message)
    end
  end

  # Streaming callback tests

  def test_streaming_callbacks_integration
    mock_output = create_mock_stream(
      {"type" => "assistant", "message" => {"content" => [
        {"type" => "text", "text" => "First message"}
      ]}},
      {"type" => "assistant", "message" => {"content" => [
        {"type" => "tool_use", "name" => "Bash", "input" => {"command" => "echo test"}}
      ]}},
      {"type" => "assistant", "message" => {"content" => [
        {"type" => "text", "text" => "Second message"}
      ]}},
      {"type" => "result", "subtype" => "success", "result" => "Complete", "success" => true}
    )
    
    callback_messages = []
    
    Open3.stub :popen3, -> (*args, &block) {
      stdin = StringIO.new
      stdout = StringIO.new(mock_output)
      stderr = StringIO.new
      wait_thread = create_success_thread
      block.call(stdin, stdout, stderr, wait_thread)
    } do
      result = AutoClaude::App.run(
        "Test streaming",
        stderr_callback: -> (msg, type, color) {
          callback_messages << {message: msg, type: type, color: color}
        }
      )
      
      assert_equal "Complete", result
      
      # Verify callbacks were called
      assert callback_messages.any? { |m| m[:message].include?("First message") }
      assert callback_messages.any? { |m| m[:message].include?("Bash") }
      assert callback_messages.any? { |m| m[:message].include?("Second message") }
    end
  end

  # Complex message type handling

  def test_handles_unknown_message_types
    mock_output = create_mock_stream(
      {"type" => "custom_type", "data" => "custom data"},
      {"type" => "assistant", "message" => {"content" => [
        {"type" => "text", "text" => "Regular message"}
      ]}},
      {"type" => "result", "subtype" => "success", "result" => "Done", "success" => true}
    )
    
    Open3.stub :popen3, -> (*args, &block) {
      stdin = StringIO.new
      stdout = StringIO.new(mock_output)
      stderr = StringIO.new
      wait_thread = create_success_thread
      block.call(stdin, stdout, stderr, wait_thread)
    } do
      # Capture warnings
      captured_stderr = StringIO.new
      original = $stderr
      $stderr = captured_stderr
      
      runner = AutoClaude::ClaudeRunner.new
      result = runner.run("Test")
      
      $stderr = original
      
      assert_equal "Done", result
      assert_match(/Unexpected message type: custom_type/, captured_stderr.string)
    end
  end

  def test_handles_malformed_json_in_stream
    # Mix valid and invalid JSON
    mock_output = [
      '{"type": "assistant", "message": {"content": [{"type": "text", "text": "Start"}]}}',
      'not valid json',
      '{"type": "assistant", "message": {"content": [{"type": "text", "text": "Continue"}]}}',
      '{"incomplete": ',
      '{"type": "result", "subtype": "success", "result": "Finished", "success": true}'
    ].join("\n") + "\n"
    
    Open3.stub :popen3, -> (*args, &block) {
      stdin = StringIO.new
      stdout = StringIO.new(mock_output)
      stderr = StringIO.new
      wait_thread = create_success_thread
      block.call(stdin, stdout, stderr, wait_thread)
    } do
      runner = AutoClaude::ClaudeRunner.new
      result = runner.run("Test")
      
      assert_equal "Finished", result
      
      output = @stderr_output.string
      assert_match(/Start/, output)
      assert_match(/Continue/, output)
    end
  end

  # Session and retry flow tests

  def test_retry_with_session_id_integration
    error_output = create_mock_stream(
      {"type" => "assistant", "message" => {"content" => [
        {"type" => "text", "text" => "Starting..."}
      ]}},
      {"type" => "result", "is_error" => true, "error" => {"message" => "Network error"}, 
       "session_id" => "session-123"}
    )
    
    success_output = create_mock_stream(
      {"type" => "assistant", "message" => {"content" => [
        {"type" => "text", "text" => "Resuming from previous session"}
      ]}},
      {"type" => "result", "subtype" => "success", "result" => "Completed after retry", 
       "success" => true}
    )
    
    call_count = 0
    captured_commands = []
    
    Open3.stub :popen3, -> (*args, &block) {
      call_count += 1
      
      # Capture the command to verify --resume was added
      if args.first.is_a?(String) && args.first.include?('claude_wrapper')
        # Read wrapper script to extract command
        wrapper_content = File.read(args.first) rescue ""
        captured_commands << wrapper_content
      end
      
      stdin = StringIO.new
      stdout = StringIO.new(call_count == 1 ? error_output : success_output)
      stderr = StringIO.new
      wait_thread = create_success_thread
      block.call(stdin, stdout, stderr, wait_thread)
    } do
      result = AutoClaude::App.run("Test with retry", retry_on_error: true)
      
      assert_equal "Completed after retry", result
      assert_equal 2, call_count
      
      # Second call should have --resume
      if captured_commands.length > 1
        assert_match(/--resume/, captured_commands[1])
        assert_match(/session-123/, captured_commands[1])
      end
    end
  end

  # Log file integration test

  def test_log_file_integration
    Tempfile.create("test_log") do |tmpfile|
      mock_output = create_mock_stream(
        {"type" => "assistant", "message" => {"content" => [
          {"type" => "text", "text" => "Logged message"}
        ]}},
        {"type" => "result", "subtype" => "success", "result" => "Done", 
         "success" => true, "session_id" => "log-test",
         "usage" => {"input_tokens" => 10, "output_tokens" => 20}}
      )
      
      Open3.stub :popen3, -> (*args, &block) {
        stdin = StringIO.new
        stdout = StringIO.new(mock_output)
        stderr = StringIO.new
        wait_thread = create_success_thread
        block.call(stdin, stdout, stderr, wait_thread)
      } do
        runner = AutoClaude::ClaudeRunner.new(log_file: tmpfile.path)
        result = runner.run("Test logging")
        
        assert_equal "Done", result
        
        # Check log file contents
        log_contents = File.read(tmpfile.path)
        assert_match(/Logged message/, log_contents)
        assert_match(/session_id/, log_contents)
        
        # Check JSON metadata was written
        lines = log_contents.lines
        json_line = lines.find { |l| l.include?('"session_id"') }
        assert json_line
        
        metadata = JSON.parse(json_line)
        assert_equal "log-test", metadata["session_id"]
      end
    end
  end

  private

  def create_success_thread
    thread = Minitest::Mock.new
    status = Process::Status.allocate
    status.instance_variable_set(:@exitstatus, 0)
    status.define_singleton_method(:success?) { true }
    status.define_singleton_method(:exitstatus) { @exitstatus }
    thread.expect :value, status
    thread
  end

  def create_failure_thread(exit_code)
    thread = Minitest::Mock.new
    status = Process::Status.allocate
    status.instance_variable_set(:@exitstatus, exit_code)
    status.define_singleton_method(:success?) { false }
    status.define_singleton_method(:exitstatus) { @exitstatus }
    thread.expect :value, status
    thread
  end
end