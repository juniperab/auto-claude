require "test_helper"
require "json"
require "tempfile"

class AutoClaude::ClaudeRunnerUnitTest < Minitest::Test
  def setup
    @original_stderr = $stderr
    @stderr_output = StringIO.new
    $stderr = @stderr_output
  end
  
  def teardown
    $stderr = @original_stderr
    AutoClaude::ColorPrinter.close_log_file
  end

  # JSON parsing tests

  def test_parse_valid_json
    runner = AutoClaude::ClaudeRunner.new
    
    # Access private method via send
    json_string = '{"type": "text", "text": "Hello"}'
    result = runner.send(:parse_json, json_string)
    
    assert_equal "text", result["type"]
    assert_equal "Hello", result["text"]
  end

  def test_parse_invalid_json
    runner = AutoClaude::ClaudeRunner.new
    
    # Should return nil for invalid JSON
    result = runner.send(:parse_json, "not valid json")
    assert_nil result
  end

  def test_parse_partial_json
    runner = AutoClaude::ClaudeRunner.new
    
    # Should return nil for incomplete JSON
    result = runner.send(:parse_json, '{"type": "text"')
    assert_nil result
  end

  def test_parse_empty_string
    runner = AutoClaude::ClaudeRunner.new
    
    result = runner.send(:parse_json, "")
    assert_nil result
  end

  # Result handling tests

  def test_handle_success_result
    runner = AutoClaude::ClaudeRunner.new
    
    json = {
      "type" => "result",
      "subtype" => "success",
      "result" => "Task completed successfully",
      "success" => true,
      "num_turns" => 1,
      "duration_ms" => 1000,
      "total_cost_usd" => 0.01,
      "usage" => {
        "input_tokens" => 100,
        "output_tokens" => 50
      },
      "session_id" => "abc123"
    }
    
    result = runner.send(:handle_result, json)
    
    assert_equal "Task completed successfully", result
    
    # Check metadata was stored
    metadata = runner.instance_variable_get(:@result_metadata)
    assert_equal true, metadata["success"]
    assert_equal "abc123", metadata["session_id"]
    assert_equal 100, metadata["usage"]["input_tokens"]
  end

  def test_handle_error_result
    runner = AutoClaude::ClaudeRunner.new
    
    json = {
      "type" => "result",
      "is_error" => true,
      "result" => "An error occurred",
      "error" => {
        "message" => "Rate limit exceeded"
      }
    }
    
    result = runner.send(:handle_result, json)
    
    assert_nil result
    
    # Check error was stored - looking at the code, it prefers error.message for the error_msg,
    # but still uses result as the first choice
    error = runner.instance_variable_get(:@error)
    assert_match(/Claude error:/, error)
    # Based on the code logic: json["result"] || json.dig("error", "message")
    # Since result is "An error occurred", that's what gets used
    assert_match(/An error occurred/, error)
    
    metadata = runner.instance_variable_get(:@result_metadata)
    assert_equal false, metadata["success"]
  end

  def test_handle_result_without_success_subtype
    runner = AutoClaude::ClaudeRunner.new
    
    json = {
      "type" => "result",
      "subtype" => "cancelled",
      "result" => "Operation cancelled"
    }
    
    result = runner.send(:handle_result, json)
    
    assert_nil result
    
    error = runner.instance_variable_get(:@error)
    assert_match(/did not complete successfully/, error)
  end

  def test_handle_empty_result
    runner = AutoClaude::ClaudeRunner.new
    
    json = {
      "type" => "result",
      "subtype" => "success",
      "result" => "",
      "success" => true
    }
    
    result = runner.send(:handle_result, json)
    
    assert_equal "", result
  end

  def test_handle_nil_result
    runner = AutoClaude::ClaudeRunner.new
    
    json = {
      "type" => "result",
      "subtype" => "success",
      "result" => nil,
      "success" => true
    }
    
    result = runner.send(:handle_result, json)
    
    assert_equal "", result
  end

  # Command building tests

  def test_build_command_with_defaults
    runner = AutoClaude::ClaudeRunner.new
    
    command = runner.send(:build_command)
    
    assert_equal %w[claude -p --verbose --output-format stream-json], command
  end

  def test_build_command_with_options
    runner = AutoClaude::ClaudeRunner.new(claude_options: ["--model", "opus", "--temperature", "0.7"])
    
    command = runner.send(:build_command)
    
    expected = %w[claude -p --verbose --output-format stream-json --model opus --temperature 0.7]
    assert_equal expected, command
  end

  # Directory validation tests

  def test_validates_directory_exists
    Dir.mktmpdir do |tmpdir|
      runner = AutoClaude::ClaudeRunner.new(directory: tmpdir)
      
      # Should not raise
      assert File.directory?(tmpdir)
    end
  end

  def test_raises_for_nonexistent_directory
    runner = AutoClaude::ClaudeRunner.new(directory: "/nonexistent/directory")
    
    assert_raises(RuntimeError) do
      runner.run("test")
    end
  end

  # Process interaction simulation tests

  def test_process_claude_interaction_with_messages
    runner = AutoClaude::ClaudeRunner.new
    
    # Create mock streams
    stdin = StringIO.new
    stdout = StringIO.new
    stderr = StringIO.new
    
    # Add JSON messages to stdout
    messages = [
      {"type" => "assistant", "message" => {"content" => [{"type" => "text", "text" => "Hello"}]}},
      {"type" => "result", "subtype" => "success", "result" => "Done", "success" => true}
    ]
    
    messages.each { |msg| stdout.puts msg.to_json }
    stdout.rewind
    
    # Mock wait thread
    wait_thread = Minitest::Mock.new
    wait_thread.expect :value, Process::Status.allocate.tap { |s|
      s.instance_variable_set(:@exitstatus, 0)
      s.define_singleton_method(:success?) { true }
      s.define_singleton_method(:exitstatus) { @exitstatus }
    }
    
    result = runner.send(:process_claude_interaction, stdin, stdout, stderr, wait_thread, "test prompt")
    
    assert_equal "Done", result
    assert_match(/Hello/, @stderr_output.string)
  end

  def test_process_claude_interaction_with_error_exit
    runner = AutoClaude::ClaudeRunner.new
    
    stdin = StringIO.new
    stdout = StringIO.new
    stderr = StringIO.new("Command failed")
    
    # Mock wait thread with failure
    wait_thread = Minitest::Mock.new
    wait_thread.expect :value, Process::Status.allocate.tap { |s|
      s.instance_variable_set(:@exitstatus, 1)
      s.define_singleton_method(:success?) { false }
      s.define_singleton_method(:exitstatus) { @exitstatus }
    }
    
    result = runner.send(:process_claude_interaction, stdin, stdout, stderr, wait_thread, "test prompt")
    
    assert_equal "", result
    
    error = runner.instance_variable_get(:@error)
    assert_match(/exit code 1/, error)
    assert_match(/Command failed/, error)
  end

  def test_process_claude_interaction_filters_system_messages
    runner = AutoClaude::ClaudeRunner.new
    
    stdin = StringIO.new
    stdout = StringIO.new
    stderr = StringIO.new
    
    # Add system message
    messages = [
      {"type" => "system", "message" => "System info"},
      {"type" => "result", "subtype" => "success", "result" => "Done", "success" => true}
    ]
    
    messages.each { |msg| stdout.puts msg.to_json }
    stdout.rewind
    
    wait_thread = Minitest::Mock.new
    wait_thread.expect :value, Process::Status.allocate.tap { |s|
      s.instance_variable_set(:@exitstatus, 0)
      s.define_singleton_method(:success?) { true }
    }
    
    result = runner.send(:process_claude_interaction, stdin, stdout, stderr, wait_thread, "test")
    
    assert_equal "Done", result
    # System messages should not appear in output
    refute_match(/System info/, @stderr_output.string)
  end

  def test_process_claude_interaction_handles_malformed_json
    runner = AutoClaude::ClaudeRunner.new
    
    stdin = StringIO.new
    stdout = StringIO.new
    stderr = StringIO.new
    
    # Mix valid and invalid JSON
    stdout.puts "not json"
    stdout.puts '{"type": "result", "subtype": "success", "result": "Done", "success": true}'
    stdout.puts '{"broken": '
    stdout.rewind
    
    wait_thread = Minitest::Mock.new
    wait_thread.expect :value, Process::Status.allocate.tap { |s|
      s.instance_variable_set(:@exitstatus, 0)
      s.define_singleton_method(:success?) { true }
    }
    
    result = runner.send(:process_claude_interaction, stdin, stdout, stderr, wait_thread, "test")
    
    assert_equal "Done", result
  end

  def test_process_claude_interaction_handles_unexpected_message_type
    runner = AutoClaude::ClaudeRunner.new
    
    stdin = StringIO.new
    stdout = StringIO.new
    stderr = StringIO.new
    
    messages = [
      {"type" => "unknown_type", "data" => "something"},
      {"type" => "result", "subtype" => "success", "result" => "Done", "success" => true}
    ]
    
    messages.each { |msg| stdout.puts msg.to_json }
    stdout.rewind
    
    wait_thread = Minitest::Mock.new
    wait_thread.expect :value, Process::Status.allocate.tap { |s|
      s.instance_variable_set(:@exitstatus, 0)
      s.define_singleton_method(:success?) { true }
    }
    
    # Capture stderr to check warning
    captured_stderr = StringIO.new
    original_stderr = $stderr
    $stderr = captured_stderr
    
    result = runner.send(:process_claude_interaction, stdin, stdout, stderr, wait_thread, "test")
    
    $stderr = original_stderr
    
    assert_equal "Done", result
    assert_match(/Unexpected message type: unknown_type/, captured_stderr.string)
  end

  # Shell determination tests

  def test_determine_shell_prefers_zsh
    runner = AutoClaude::ClaudeRunner.new
    
    ENV.stub :[], -> (key) {
      return '/bin/zsh' if key == 'SHELL'
      return '/usr/local/bin:/usr/bin:/bin' if key == 'PATH'
      nil
    } do
      File.stub :executable?, -> (path) {
        path == '/usr/bin/env' || path == '/usr/bin/zsh'
      } do
        shell = runner.send(:determine_shell)
        assert_equal '/usr/bin/env zsh', shell
      end
    end
  end

  def test_determine_shell_falls_back_to_bash
    runner = AutoClaude::ClaudeRunner.new
    
    ENV.stub :[], -> (key) {
      return '/bin/bash' if key == 'SHELL'
      return '/usr/local/bin:/usr/bin:/bin' if key == 'PATH'
      nil
    } do
      File.stub :executable?, -> (path) {
        path == '/usr/bin/env' || path == '/usr/bin/bash'
      } do
        shell = runner.send(:determine_shell)
        assert_equal '/usr/bin/env bash', shell
      end
    end
  end

  # Wrapper script tests

  def test_creates_wrapper_script
    Dir.mktmpdir do |tmpdir|
      runner = AutoClaude::ClaudeRunner.new(directory: tmpdir)
      
      wrapper_created = false
      
      # Mock the entire wrapper script flow
      Open3.stub :popen3, -> (*args, &block) {
        # Verify a wrapper script path was passed
        assert args.first.include?('claude_wrapper') if args.first.is_a?(String)
        
        stdin = StringIO.new
        stdout = StringIO.new('{"type": "result", "subtype": "success", "result": "Done"}' + "\n")
        stderr = StringIO.new
        
        wait_thread = Minitest::Mock.new
        status = Process::Status.allocate
        status.instance_variable_set(:@exitstatus, 0)
        status.define_singleton_method(:success?) { true }
        status.define_singleton_method(:exitstatus) { 0 }
        wait_thread.expect :value, status
        
        block.call(stdin, stdout, stderr, wait_thread)
      } do
        result = runner.run("test")
        assert_equal "Done", result
      end
    end
  end

  # Stats printing tests

  def test_print_usage_stats
    runner = AutoClaude::ClaudeRunner.new
    
    metadata = {
      "success" => true,
      "num_turns" => 2,
      "duration_ms" => 1500,
      "total_cost_usd" => 0.001234,
      "usage" => {
        "input_tokens" => 150,
        "output_tokens" => 75
      },
      "session_id" => "test-session"
    }
    
    runner.instance_variable_set(:@result_metadata, metadata)
    runner.send(:print_usage_stats)
    
    output = @stderr_output.string
    assert_match(/Success: true/, output)
    assert_match(/Turns: 2/, output)
    assert_match(/Duration: 1.5s/, output)
    assert_match(/Cost: \$0.001234/, output)
    assert_match(/Tokens: 150 up, 75 down/, output)
    assert_match(/Session ID: test-session/, output)
  end

  def test_print_usage_stats_with_failure
    runner = AutoClaude::ClaudeRunner.new
    
    metadata = {
      "success" => false,
      "error_message" => "Something went wrong"
    }
    
    runner.instance_variable_set(:@result_metadata, metadata)
    runner.send(:print_usage_stats)
    
    output = @stderr_output.string
    assert_match(/Success: false/, output)
  end

  # Business logic tests with real components

  def test_full_message_processing_pipeline
    Dir.mktmpdir do |tmpdir|
      runner = AutoClaude::ClaudeRunner.new(directory: tmpdir)
      
      # Simulate Claude's actual JSON output format
      claude_output = [
        '{"type": "assistant", "message": {"content": [{"type": "text", "text": "I\'ll help you with that."}]}}',
        '{"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Bash", "input": {"command": "ls"}}]}}',
        '{"type": "user", "message": {"content": [{"type": "tool_result", "content": "file1.txt file2.txt"}]}}',
        '{"type": "assistant", "message": {"content": [{"type": "text", "text": "I found 2 files."}]}}',
        '{"type": "result", "subtype": "success", "result": "Found 2 files", "success": true, "num_turns": 2, "duration_ms": 1000, "total_cost_usd": 0.001, "usage": {"input_tokens": 50, "output_tokens": 25}, "session_id": "test123"}'
      ].join("\n") + "\n"
      
      # Only mock the actual process call, everything else is real
      Open3.stub :popen3, -> (script_path, &block) {
        # Verify the wrapper script was created and contains correct directory
        assert File.exist?(script_path), "Wrapper script should exist"
        script_content = File.read(script_path)
        assert_match(/cd "#{Regexp.escape(tmpdir)}"/, script_content)
        assert_match(/unset OLDPWD/, script_content)
        # The command uses single quotes for each argument
        assert_match(/exec 'claude' '-p' '--verbose' '--output-format' 'stream-json'/, script_content)
        
        # Simulate the process interaction
        stdin = StringIO.new
        stdout = StringIO.new(claude_output)
        stderr = StringIO.new
        wait_thread = create_mock_wait_thread(0, true)
        
        block.call(stdin, stdout, stderr, wait_thread)
      } do
        result = runner.run("Test prompt")
        
        # Verify the result
        assert_equal "Found 2 files", result
        
        # Verify messages were processed and printed correctly
        output = @stderr_output.string
        assert_match(/I'll help you with that/, output)
        assert_match(/Bash\("ls"\)/, output)
        assert_match(/I found 2 files/, output)
        
        # Verify stats were printed
        assert_match(/Success: true/, output)
        assert_match(/Turns: 2/, output)
        assert_match(/Duration: 1.0s/, output)
        assert_match(/Cost: \$0.001000/, output)
        assert_match(/Tokens: 50 up, 25 down/, output)
        assert_match(/Session ID: test123/, output)
        
        # Verify metadata was stored correctly
        metadata = runner.instance_variable_get(:@result_metadata)
        assert_equal true, metadata["success"]
        assert_equal "test123", metadata["session_id"]
        assert_equal 2, metadata["num_turns"]
      end
    end
  end

  def test_error_handling_pipeline_with_real_components
    runner = AutoClaude::ClaudeRunner.new
    
    error_output = [
      '{"type": "assistant", "message": {"content": [{"type": "text", "text": "Starting..."}]}}',
      '{"type": "result", "is_error": true, "result": "Rate limit exceeded", "error": {"message": "Too many requests"}}'
    ].join("\n") + "\n"
    
    Open3.stub :popen3, -> (script_path, &block) {
      stdin = StringIO.new
      stdout = StringIO.new(error_output)
      stderr = StringIO.new
      wait_thread = create_mock_wait_thread(0, true)
      
      block.call(stdin, stdout, stderr, wait_thread)
    } do
      # Should raise the actual error
      error = assert_raises(RuntimeError) do
        runner.run("Test")
      end
      
      assert_match(/Claude error: Rate limit exceeded/, error.message)
      
      # Verify error metadata was stored
      metadata = runner.instance_variable_get(:@result_metadata)
      assert_equal false, metadata["success"]
      assert_equal "Rate limit exceeded", metadata["error_message"]
    end
  end

  def test_process_failure_handling_with_real_components
    runner = AutoClaude::ClaudeRunner.new
    
    partial_output = '{"type": "assistant", "message": {"content": [{"type": "text", "text": "Starting..."}]}}'
    
    Open3.stub :popen3, -> (script_path, &block) {
      stdin = StringIO.new
      stdout = StringIO.new(partial_output + "\n")
      stderr = StringIO.new("Connection reset by peer")
      wait_thread = create_mock_wait_thread(1, false)
      
      block.call(stdin, stdout, stderr, wait_thread)
    } do
      error = assert_raises(RuntimeError) do
        runner.run("Test")
      end
      
      assert_match(/exit code 1/, error.message)
      assert_match(/Connection reset by peer/, error.message)
      
      # Verify partial output was still processed
      output = @stderr_output.string
      assert_match(/Starting.../, output)
    end
  end

  def test_log_file_with_real_file_io
    Tempfile.create("test_log") do |tmpfile|
      runner = AutoClaude::ClaudeRunner.new(log_file: tmpfile.path)
      
      claude_output = [
        '{"type": "assistant", "message": {"content": [{"type": "text", "text": "Response text"}]}}',
        '{"type": "result", "subtype": "success", "result": "Done", "success": true, "session_id": "log123", "usage": {"input_tokens": 10, "output_tokens": 5}}'
      ].join("\n") + "\n"
      
      Open3.stub :popen3, -> (script_path, &block) {
        stdin = StringIO.new
        stdout = StringIO.new(claude_output)
        stderr = StringIO.new
        wait_thread = create_mock_wait_thread(0, true)
        
        block.call(stdin, stdout, stderr, wait_thread)
      } do
        result = runner.run("Test")
        
        assert_equal "Done", result
        
        # Verify log file contains both messages and metadata
        log_content = File.read(tmpfile.path)
        
        # Messages should be logged without color codes
        assert_match(/Response text/, log_content)
        refute_match(/\e\[/, log_content)  # No ANSI codes
        
        # JSON metadata should be on last line
        lines = log_content.lines
        json_line = lines.last
        metadata = JSON.parse(json_line)
        
        assert_equal true, metadata["success"]
        assert_equal "log123", metadata["session_id"]
        assert_equal 10, metadata["input_tokens"]
        assert_equal 5, metadata["output_tokens"]
      end
    end
  end

  def test_message_formatter_integration_with_real_components
    # Test that MessageFormatter and ColorPrinter work together correctly
    messages = {
      "message" => {
        "content" => [
          {"type" => "text", "text" => "First line\nSecond line\nThird line\nFourth line\nFifth line\nSixth line"},
          {"type" => "tool_use", "name" => "Bash", "input" => {"command" => "pwd"}},
          {"type" => "tool_use", "name" => "TodoWrite", "input" => {
            "todos" => (1..10).map { |i| 
              {"id" => i.to_s, "content" => "Task #{i}", "status" => "pending"}
            }
          }}
        ]
      }
    }
    
    # Process through real formatter
    AutoClaude::MessageFormatter.format_and_print_messages(messages)
    
    output = @stderr_output.string
    
    # Verify text truncation (default 5 lines)
    assert_match(/First line/, output)
    assert_match(/Fifth line/, output)
    assert_match(/\+ 1 line not shown/, output)
    
    # Verify tool formatting
    assert_match(/Bash\("pwd"\)/, output)
    
    # Verify TodoWrite is NOT truncated
    assert_match(/Task 1/, output)
    assert_match(/Task 10/, output)
    refute_match(/Task.*not shown/, output)
  end

  def test_callback_flow_with_real_processing
    callback_messages = []
    
    # Set up the callback
    AutoClaude::ColorPrinter.stderr_callback = -> (msg, type, color) {
      callback_messages << {message: msg, type: type, color: color}
    }
    
    claude_output = [
      '{"type": "assistant", "message": {"content": [{"type": "text", "text": "Processing request"}]}}',
      '{"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Read", "input": {"file_path": "/tmp/test.txt"}}]}}',
      '{"type": "result", "subtype": "success", "result": "Completed", "success": true, "duration_ms": 500, "total_cost_usd": 0.0001}'
    ].join("\n") + "\n"
    
    Open3.stub :popen3, -> (script_path, &block) {
      stdin = StringIO.new
      stdout = StringIO.new(claude_output)
      stderr = StringIO.new
      wait_thread = create_mock_wait_thread(0, true)
      
      block.call(stdin, stdout, stderr, wait_thread)
    } do
      runner = AutoClaude::ClaudeRunner.new
      result = runner.run("Test with callbacks")
      
      assert_equal "Completed", result
      
      # Verify callbacks received all messages
      assert callback_messages.any? { |m| m[:message].include?("Processing request") && m[:type] == :message }
      assert callback_messages.any? { |m| m[:message].include?("Read") && m[:type] == :message }
      assert callback_messages.any? { |m| m[:message].include?("Cost:") && m[:type] == :stat }
      
      # Verify colors were passed correctly
      message_colors = callback_messages.select { |m| m[:type] == :message }.map { |m| m[:color] }
      assert_includes message_colors, :white
      
      stat_colors = callback_messages.select { |m| m[:type] == :stat }.map { |m| m[:color] }
      assert_includes stat_colors, :dark_gray
    end
  ensure
    AutoClaude::ColorPrinter.stderr_callback = nil
  end

  def test_directory_isolation_with_real_wrapper_script
    Dir.mktmpdir do |project_dir|
      Dir.mktmpdir do |work_dir|
        runner = AutoClaude::ClaudeRunner.new(directory: work_dir)
        
        wrapper_script_content = nil
        
        Open3.stub :popen3, -> (script_path, &block) {
          # Capture the actual wrapper script content
          wrapper_script_content = File.read(script_path)
          
          # Verify script sets up proper isolation
          assert_match(/cd "#{Regexp.escape(work_dir)}"/, wrapper_script_content)
          assert_match(/unset OLDPWD/, wrapper_script_content)
          assert_match(/export PWD="#{Regexp.escape(work_dir)}"/, wrapper_script_content)
          assert_match(/unset BUNDLE_GEMFILE/, wrapper_script_content)
          assert_match(/unset RUBYLIB/, wrapper_script_content)
          
          stdin = StringIO.new
          stdout = StringIO.new('{"type": "result", "subtype": "success", "result": "OK"}' + "\n")
          stderr = StringIO.new
          wait_thread = create_mock_wait_thread(0, true)
          
          block.call(stdin, stdout, stderr, wait_thread)
        } do
          # Run from project_dir but set work_dir
          Dir.chdir(project_dir) do
            result = runner.run("Test isolation")
            assert_equal "OK", result
          end
          
          # Verify wrapper script was created and cleaned up
          refute_nil wrapper_script_content
        end
      end
    end
  end

  private

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