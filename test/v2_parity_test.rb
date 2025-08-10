require "test_helper"
require "auto_claude/v2"

class V2ParityTest < Minitest::Test
  def setup
    @mock_response = <<~JSON
      {"type": "assistant", "message": {"content": [{"type": "text", "text": "Test response"}]}}
      {"type": "result", "subtype": "success", "result": "Test complete", "success": true, "num_turns": 1, "duration_ms": 100, "total_cost_usd": 0.0001, "usage": {"input_tokens": 10, "output_tokens": 5}}
    JSON
  end

  def test_basic_run_compatibility
    # V1 style
    v1_result = nil
    Open3.stub :popen3, create_mock_popen(@mock_response) do
      v1_result = AutoClaude::App.run("Test prompt")
    end
    
    # V2 style  
    v2_result = nil
    Open3.stub :popen3, create_mock_popen(@mock_response) do
      v2_result = AutoClaude::V2.run("Test prompt", output: AutoClaude::V2::Output::Memory.new)
    end
    
    assert_equal "Test complete", v1_result
    assert_equal "Test complete", v2_result
  end

  def test_directory_option
    Dir.mktmpdir do |tmpdir|
      # Both should accept directory option
      Open3.stub :popen3, -> (script_path, &block) {
        # Verify wrapper script sets correct directory
        if File.exist?(script_path)
          content = File.read(script_path)
          assert_match(/cd "#{Regexp.escape(tmpdir)}"/, content)
        end
        create_mock_popen(@mock_response).call(script_path, &block)
      } do
        # V1
        AutoClaude::App.run("Test", directory: tmpdir)
        
        # V2
        client = AutoClaude::V2::Client.new(directory: tmpdir, output: AutoClaude::V2::Output::Memory.new)
        client.run("Test")
      end
    end
  end

  def test_claude_options
    mock_manager = Minitest::Mock.new
    mock_manager.expect :execute, nil, ["Test", stream_handler: Object]
    
    # V2 accepts claude options
    AutoClaude::V2::Process::Manager.stub :new, mock_manager do
      client = AutoClaude::V2::Client.new(
        claude_options: ["--model", "opus"],
        output: AutoClaude::V2::Output::Memory.new
      )
      # Manager.new is called with claude_options during session.execute
    end
  end

  def test_error_handling
    error_response = <<~JSON
      {"type": "result", "is_error": true, "result": "Error occurred"}
    JSON
    
    # V1 raises error
    Open3.stub :popen3, create_mock_popen(error_response) do
      assert_raises(RuntimeError) do
        AutoClaude::App.run("Test")
      end
    end
    
    # V2 session shows error
    Open3.stub :popen3, create_mock_popen(error_response) do
      client = AutoClaude::V2::Client.new(output: AutoClaude::V2::Output::Memory.new)
      session = client.run("Test")
      
      assert session.error?
      refute session.success?
      assert_equal "Error occurred", session.result.error_message
    end
  end

  def test_cli_interface_exists
    # V2 has CLI class
    assert defined?(AutoClaude::V2::CLI)
    assert AutoClaude::V2::CLI.respond_to?(:run)
  end

  def test_output_formats
    # V2 supports multiple output formats
    assert defined?(AutoClaude::V2::Output::Terminal)
    assert defined?(AutoClaude::V2::Output::Memory)
    assert defined?(AutoClaude::V2::Output::File)
    assert defined?(AutoClaude::V2::Output::Multiplexer)
  end

  def test_message_types
    # V2 has all message types
    assert defined?(AutoClaude::V2::Messages::TextMessage)
    assert defined?(AutoClaude::V2::Messages::ToolUseMessage)
    assert defined?(AutoClaude::V2::Messages::ToolResultMessage)
    assert defined?(AutoClaude::V2::Messages::ResultMessage)
    assert defined?(AutoClaude::V2::Messages::SystemMessage)
  end

  def test_session_metadata
    Open3.stub :popen3, create_mock_popen(@mock_response) do
      client = AutoClaude::V2::Client.new(output: AutoClaude::V2::Output::Memory.new)
      session = client.run("Test")
      
      # V2 provides rich session data
      assert session.id
      assert_equal 0.0001, session.cost
      assert_equal({input: 10, output: 5}, session.token_usage)
      assert session.duration
      assert session.success?
    end
  end

  def test_concurrent_sessions
    # V2 supports concurrent sessions
    client = AutoClaude::V2::Client.new(output: AutoClaude::V2::Output::Memory.new)
    
    Open3.stub :popen3, create_mock_popen(@mock_response) do
      threads = 3.times.map { client.run_async("Test") }
      sessions = threads.map(&:value)
      
      assert_equal 3, sessions.count
      assert_equal 3, sessions.map(&:id).uniq.count
    end
  end

  private

  def create_mock_popen(stdout_content, exit_code = 0)
    -> (script_path, &block) {
      stdin = StringIO.new
      stdout = StringIO.new(stdout_content)
      stderr = StringIO.new
      
      wait_thread = Minitest::Mock.new
      status = Process::Status.allocate
      status.instance_variable_set(:@exitstatus, exit_code)
      status.define_singleton_method(:success?) { exit_code == 0 }
      status.define_singleton_method(:exitstatus) { @exitstatus }
      wait_thread.expect :value, status
      
      block.call(stdin, stdout, stderr, wait_thread)
    }
  end
end