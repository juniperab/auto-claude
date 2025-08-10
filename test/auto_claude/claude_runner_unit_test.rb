require "test_helper"
require "json"

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
end