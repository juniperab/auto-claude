require "test_helper"
require "tempfile"
require "json"

class AutoClaude::AppTest < Minitest::Test
  def setup
    # Mock the ClaudeRunner to avoid actual Claude API calls
    @mock_runner = Minitest::Mock.new
    @original_claude_runner = AutoClaude::ClaudeRunner
    
    # Stub ClaudeRunner.new to return our mock
    AutoClaude::ClaudeRunner.stub :new, @mock_runner do
      yield if block_given?
    end
  end
  
  def teardown
    # Clean up any state
    AutoClaude::ColorPrinter.stderr_callback = nil
    AutoClaude::ColorPrinter.close_log_file
  end

  def test_basic_run
    # Setup mock to return a simple result
    @mock_runner.expect :run, "4", ["What is 2+2?"]
    
    AutoClaude::ClaudeRunner.stub :new, @mock_runner do
      result = AutoClaude::App.run("What is 2+2?")
      assert_equal "4", result
    end
    
    @mock_runner.verify
  end

  def test_run_with_directory
    # Setup mock with directory expectation
    expected_dir = "/tmp"
    @mock_runner.expect :run, "file1.txt file2.txt", ["List files"]
    
    # Capture the directory that was passed to ClaudeRunner.new
    actual_options = nil
    AutoClaude::ClaudeRunner.stub :new, -> (opts) { 
      actual_options = opts
      @mock_runner 
    } do
      result = AutoClaude::App.run("List files", directory: expected_dir)
      assert_equal "file1.txt file2.txt", result
      assert_equal expected_dir, actual_options[:directory]
    end
    
    @mock_runner.verify
  end

  def test_run_with_log_file
    Tempfile.create("test_log") do |tmpfile|
      @mock_runner.expect :run, "test result", ["Test prompt"]
      
      actual_options = nil
      AutoClaude::ClaudeRunner.stub :new, -> (opts) { 
        actual_options = opts
        @mock_runner 
      } do
        result = AutoClaude::App.run("Test prompt", log_file: tmpfile.path)
        assert_equal "test result", result
        assert_equal tmpfile.path, actual_options[:log_file]
      end
      
      @mock_runner.verify
    end
  end

  def test_run_with_claude_options
    @mock_runner.expect :run, "result", ["prompt"]
    
    actual_options = nil
    AutoClaude::ClaudeRunner.stub :new, -> (opts) { 
      actual_options = opts
      @mock_runner 
    } do
      result = AutoClaude::App.run("prompt", claude_options: ["--model", "opus"])
      assert_equal "result", result
      assert_equal ["--model", "opus"], actual_options[:claude_options]
    end
    
    @mock_runner.verify
  end

  def test_run_with_invalid_claude_options
    assert_raises(RuntimeError) do
      AutoClaude::App.run("test", claude_options: ["--verbose"])
    end
  end

  def test_run_with_custom_output_streams
    output = StringIO.new
    error = StringIO.new
    
    @mock_runner.expect :run, "Hello World", ["Hello"]
    
    AutoClaude::ClaudeRunner.stub :new, @mock_runner do
      result = AutoClaude::App.run("Hello", output: output, error: error)
      assert_equal "Hello World", result
    end
    
    @mock_runner.verify
  end

  def test_run_with_retry_on_error
    # First attempt fails
    error_runner = Object.new
    def error_runner.run(input)
      raise "Network error"
    end
    def error_runner.instance_variable_get(var)
      {"session_id" => "abc123"} if var == :@result_metadata
    end
    
    # Second attempt succeeds  
    success_runner = Minitest::Mock.new
    success_runner.expect :run, "Success", ["Test"]
    
    call_count = 0
    AutoClaude::ClaudeRunner.stub :new, -> (opts) {
      call_count += 1
      if call_count == 1
        error_runner
      else
        # Verify resume was added
        assert_includes opts[:claude_options], "--resume"
        assert_includes opts[:claude_options], "abc123"
        success_runner
      end
    } do
      error_output = StringIO.new
      result = AutoClaude::App.run("Test", retry_on_error: true, error: error_output)
      assert_equal "Success", result
      assert_match(/Retrying with --resume/, error_output.string)
    end
    
    success_runner.verify
  end

  def test_run_raises_on_error_without_retry
    error_runner = Object.new
    def error_runner.run(input)
      raise "Fatal error"
    end
    def error_runner.instance_variable_get(var)
      nil
    end
    
    AutoClaude::ClaudeRunner.stub :new, error_runner do
      assert_raises(RuntimeError) do
        AutoClaude::App.run("Test", retry_on_error: false)
      end
    end
  end

  # Business logic tests with real ClaudeRunner
  
  def test_app_run_with_real_claude_runner
    output = StringIO.new
    error = StringIO.new
    
    claude_response = create_claude_response(
      {"type" => "assistant", "message" => {"content" => [
        {"type" => "text", "text" => "The answer is 42"}
      ]}},
      {"type" => "result", "subtype" => "success", "result" => "The answer is 42", 
       "success" => true, "num_turns" => 1, "duration_ms" => 500,
       "total_cost_usd" => 0.0001, "usage" => {"input_tokens" => 10, "output_tokens" => 5}}
    )
    
    # Only mock the actual process call to Claude
    Open3.stub :popen3, create_process_stub(claude_response) do
      result = AutoClaude::App.run(
        "What is the meaning of life?",
        output: output,
        error: error
      )
      
      # Verify the result
      assert_equal "The answer is 42", result
      
      # Verify output streams
      assert_equal "", output.string  # Nothing should go to stdout during run
      
      # Error stream should have the formatted messages and stats
      error_output = error.string
      assert_match(/The answer is 42/, error_output)
      assert_match(/Success: true/, error_output)
      assert_match(/Cost:/, error_output)
    end
  end

  def test_app_run_directory_with_real_wrapper_script
    Dir.mktmpdir do |tmpdir|
      output = StringIO.new
      error = StringIO.new
      
      claude_response = create_claude_response(
        {"type" => "result", "subtype" => "success", "result" => "Listed files"}
      )
      
      wrapper_script_verified = false
      
      Open3.stub :popen3, -> (script_path, &block) {
        # Verify the wrapper script sets the correct directory
        if File.exist?(script_path)
          script_content = File.read(script_path)
          wrapper_script_verified = script_content.include?("cd \"#{tmpdir}\"")
        end
        
        create_process_stub(claude_response).call(script_path, &block)
      } do
        result = AutoClaude::App.run(
          "List files",
          directory: tmpdir,
          output: output,
          error: error
        )
        
        assert_equal "Listed files", result
        assert wrapper_script_verified, "Wrapper script should set correct directory"
        
        # Verify directory was shown in output
        assert_match(/Working directory:.*#{Regexp.escape(tmpdir)}/, error.string)
      end
    end
  end

  def test_app_run_log_file_with_real_file_io
    Tempfile.create("app_test_log") do |tmpfile|
      claude_response = create_claude_response(
        {"type" => "assistant", "message" => {"content" => [
          {"type" => "text", "text" => "This should be logged"}
        ]}},
        {"type" => "result", "subtype" => "success", "result" => "Done", 
         "success" => true, "session_id" => "log456",
         "usage" => {"input_tokens" => 20, "output_tokens" => 10}}
      )
      
      Open3.stub :popen3, create_process_stub(claude_response) do
        result = AutoClaude::App.run(
          "Test logging",
          log_file: tmpfile.path
        )
        
        assert_equal "Done", result
        
        # Verify log file was written
        log_content = File.read(tmpfile.path)
        
        # Should contain the message without ANSI codes
        assert_match(/This should be logged/, log_content)
        refute_match(/\e\[/, log_content)
        
        # Should contain JSON metadata
        json_line = log_content.lines.find { |l| l.include?('"session_id"') }
        assert json_line, "Log should contain JSON metadata"
        
        metadata = JSON.parse(json_line)
        assert_equal "log456", metadata["session_id"]
        assert_equal 20, metadata["input_tokens"]
      end
    end
  end

  def test_app_run_callbacks_with_real_components
    callback_messages = []
    
    claude_response = create_claude_response(
      {"type" => "assistant", "message" => {"content" => [
        {"type" => "text", "text" => "First message"}
      ]}},
      {"type" => "assistant", "message" => {"content" => [
        {"type" => "tool_use", "name" => "Bash", "input" => {"command" => "echo hello"}}
      ]}},
      {"type" => "result", "subtype" => "success", "result" => "Complete"}
    )
    
    Open3.stub :popen3, create_process_stub(claude_response) do
      result = AutoClaude::App.run(
        "Test callbacks",
        stderr_callback: -> (msg, type, color) {
          callback_messages << {message: msg, type: type, color: color}
        }
      )
      
      assert_equal "Complete", result
      
      # Verify callbacks were called with correct data
      assert callback_messages.any? { |m| 
        m[:message].include?("First message") && m[:type] == :message 
      }
      assert callback_messages.any? { |m| 
        m[:message].include?("Bash") && m[:type] == :message 
      }
      assert callback_messages.any? { |m| 
        m[:type] == :stat 
      }
    end
  end

  def test_app_run_retry_with_real_session_handling
    call_count = 0
    captured_commands = []
    
    error_response = create_claude_response(
      {"type" => "result", "is_error" => true, "result" => "Network error", 
       "session_id" => "retry123"}
    )
    
    success_response = create_claude_response(
      {"type" => "assistant", "message" => {"content" => [
        {"type" => "text", "text" => "Resumed successfully"}
      ]}},
      {"type" => "result", "subtype" => "success", "result" => "Success after retry"}
    )
    
    Open3.stub :popen3, -> (script_path, &block) {
      call_count += 1
      
      # Capture the command from the wrapper script
      if File.exist?(script_path)
        script_content = File.read(script_path)
        if script_content =~ /exec (.*claude.*)/
          captured_commands << $1
        end
      end
      
      response = call_count == 1 ? error_response : success_response
      create_process_stub(response).call(script_path, &block)
    } do
      error_output = StringIO.new
      
      result = AutoClaude::App.run(
        "Test retry",
        retry_on_error: true,
        error: error_output
      )
      
      assert_equal "Success after retry", result
      assert_equal 2, call_count
      
      # Verify second attempt included --resume
      assert captured_commands.length == 2
      refute_match(/--resume/, captured_commands[0])
      assert_match(/--resume.*retry123/, captured_commands[1])
      
      # Verify retry message was shown
      assert_match(/Retrying with --resume/, error_output.string)
    end
  end

  private

  def create_claude_response(*messages)
    messages.map { |msg| msg.to_json }.join("\n") + "\n"
  end

  def create_process_stub(response_data)
    -> (script_path, &block) {
      stdin = StringIO.new
      stdout = StringIO.new(response_data)
      stderr = StringIO.new
      wait_thread = create_mock_wait_thread(0, true)
      block.call(stdin, stdout, stderr, wait_thread)
    }
  end

  def create_mock_wait_thread(exit_code, success)
    thread = Minitest::Mock.new
    status = Process::Status.allocate
    status.instance_variable_set(:@exitstatus, exit_code)
    status.define_singleton_method(:success?) { success }
    status.define_singleton_method(:exitstatus) { @exitstatus }
    thread.expect :value, status
    thread
  end
end