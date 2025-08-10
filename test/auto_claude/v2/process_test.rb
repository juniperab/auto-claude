require "test_helper"
require "auto_claude/v2/process/manager"
require "auto_claude/v2/process/wrapper"
require "auto_claude/v2/process/stream_parser"
require "auto_claude/v2/messages/base"

class AutoClaude::V2::ProcessTest < Minitest::Test
  def test_wrapper_creates_executable_script
    Dir.mktmpdir do |tmpdir|
      wrapper = AutoClaude::V2::Process::Wrapper.new(tmpdir)
      
      command = ["claude", "-p", "--verbose"]
      script_path = wrapper.create_script(command)
      
      assert File.exist?(script_path)
      assert File.executable?(script_path)
      
      content = File.read(script_path)
      assert_match(/cd "#{Regexp.escape(tmpdir)}"/, content)
      assert_match(/exec claude/, content)
      
      wrapper.cleanup
      refute File.exist?(script_path)
    end
  end

  def test_wrapper_determines_shell
    wrapper = AutoClaude::V2::Process::Wrapper.new(Dir.pwd)
    
    ENV.stub :[], -> (key) {
      return '/bin/zsh' if key == 'SHELL'
      nil
    } do
      File.stub :executable?, -> (path) {
        path == '/usr/bin/env' || path == '/usr/bin/zsh'
      } do
        shell = wrapper.send(:determine_shell)
        assert_equal '/usr/bin/env zsh', shell
      end
    end
  end

  def test_stream_parser_parses_json_lines
    messages_received = []
    handler = -> (msg) { messages_received << msg }
    
    parser = AutoClaude::V2::Process::StreamParser.new(handler)
    
    stream = StringIO.new(<<~JSON)
      {"type": "assistant", "message": {"content": [{"type": "text", "text": "Hello"}]}}
      {"type": "system", "message": "System info"}
      not json
      {"type": "result", "subtype": "success", "result": "Done"}
    JSON
    
    parser.parse(stream)
    
    # Should have 2 messages (system filtered, invalid json ignored)
    assert_equal 2, messages_received.count
    assert_kind_of AutoClaude::V2::Messages::TextMessage, messages_received[0]
    assert_kind_of AutoClaude::V2::Messages::ResultMessage, messages_received[1]
  end

  def test_manager_validates_directory
    assert_raises(ArgumentError) do
      AutoClaude::V2::Process::Manager.new(
        directory: "/nonexistent/path",
        claude_options: []
      )
    end
  end

  def test_manager_validates_claude_options
    assert_raises(ArgumentError) do
      AutoClaude::V2::Process::Manager.new(
        directory: Dir.pwd,
        claude_options: ["--verbose"] # Forbidden option
      )
    end
    
    assert_raises(ArgumentError) do
      AutoClaude::V2::Process::Manager.new(
        directory: Dir.pwd,
        claude_options: ["--output-format", "json"]
      )
    end
  end

  def test_manager_builds_correct_command
    manager = AutoClaude::V2::Process::Manager.new(
      directory: Dir.pwd,
      claude_options: ["--model", "opus"]
    )
    
    command = manager.send(:build_command)
    
    assert_equal ["claude", "-p", "--verbose", "--output-format", "stream-json", "--model", "opus"], command
  end

  def test_manager_execute_with_mock_process
    messages_received = []
    
    manager = AutoClaude::V2::Process::Manager.new(
      directory: Dir.pwd,
      claude_options: []
    )
    
    mock_output = <<~JSON
      {"type": "assistant", "message": {"content": [{"type": "text", "text": "Processing"}]}}
      {"type": "result", "subtype": "success", "result": "Complete", "success": true}
    JSON
    
    Open3.stub :popen3, create_mock_popen(mock_output, 0) do
      manager.execute("test prompt", stream_handler: -> (msg) {
        messages_received << msg
      })
    end
    
    assert_equal 2, messages_received.count
    assert_equal "Processing", messages_received[0].text
    assert_equal "Complete", messages_received[1].content
  end

  def test_manager_execute_handles_process_failure
    manager = AutoClaude::V2::Process::Manager.new(
      directory: Dir.pwd,
      claude_options: []
    )
    
    Open3.stub :popen3, create_mock_popen("", 1, "Command failed") do
      error = assert_raises(RuntimeError) do
        manager.execute("test", stream_handler: -> (msg) {})
      end
      
      assert_match(/exit code 1/, error.message)
      assert_match(/Command failed/, error.message)
    end
  end

  private

  def create_mock_popen(stdout_content, exit_code = 0, stderr_content = "")
    -> (script_path, &block) {
      stdin = StringIO.new
      stdout = StringIO.new(stdout_content)
      stderr = StringIO.new(stderr_content)
      
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