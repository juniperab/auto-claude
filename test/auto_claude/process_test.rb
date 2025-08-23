# frozen_string_literal: true

require "test_helper"
require "auto_claude/process/manager"
require "auto_claude/process/wrapper"
require "auto_claude/process/stream_parser"
require "auto_claude/messages/base"

module AutoClaude
  class ProcessTest < Minitest::Test
    def test_wrapper_creates_executable_script
      Dir.mktmpdir do |tmpdir|
        wrapper = AutoClaude::Process::Wrapper.new(tmpdir)

        command = ["claude", "-p", "--verbose"]
        script_path = wrapper.create_script(command)

        assert_path_exists script_path
        assert File.executable?(script_path)

        content = File.read(script_path)

        assert_match(/cd "#{Regexp.escape(tmpdir)}"/, content)
        assert_match(/exec claude/, content)

        wrapper.cleanup

        refute_path_exists script_path
      end
    end

    def test_wrapper_determines_shell
      wrapper = AutoClaude::Process::Wrapper.new(Dir.pwd)

      # Test actual shell detection based on current environment
      shell = wrapper.send(:determine_shell)

      # Shell should be one of the valid options
      valid_shells = [
        "/usr/bin/env zsh",
        "/usr/bin/env bash",
        "/bin/bash"
      ]

      assert_includes valid_shells, shell, "Shell should be a valid shell path"

      # If /usr/bin/env exists, it should be used
      if File.executable?("/usr/bin/env")
        assert_match(%r{^/usr/bin/env}, shell)
      else
        assert_equal "/bin/bash", shell
      end
    end

    def test_wrapper_shell_detection_with_zsh_preference
      # This test documents the zsh preference behavior
      # It will pass differently on different systems, which is correct
      wrapper = AutoClaude::Process::Wrapper.new(Dir.pwd)

      if ENV["SHELL"]&.include?("zsh") && File.executable?("/usr/bin/env")
        # If user has zsh and env is available, we prefer it
        zsh_available = %w[/usr/bin/zsh /bin/zsh /usr/local/bin/zsh].any? { |p| File.executable?(p) }

        shell = wrapper.send(:determine_shell)

        if zsh_available
          assert_equal "/usr/bin/env zsh", shell, "Should prefer zsh when available"
        else
          assert_equal "/usr/bin/env bash", shell, "Should fall back to bash when zsh not found"
        end
      else
        # This branch documents behavior on non-zsh systems
        assert true, "Skipping zsh preference test on non-zsh system"
      end
    end

    def test_stream_parser_parses_json_lines
      messages_received = []
      handler = ->(msg) { messages_received << msg }

      parser = AutoClaude::Process::StreamParser.new(handler)

      stream = StringIO.new(<<~JSON)
        {"type": "assistant", "message": {"content": [{"type": "text", "text": "Hello"}]}}
        {"type": "system", "message": "System info"}
        not json
        {"type": "result", "subtype": "success", "result": "Done"}
      JSON

      parser.parse(stream)

      # Should have 2 messages (system filtered, invalid json ignored)
      assert_equal 2, messages_received.count
      assert_kind_of AutoClaude::Messages::TextMessage, messages_received[0]
      assert_kind_of AutoClaude::Messages::ResultMessage, messages_received[1]
    end

    def test_manager_validates_directory
      assert_raises(ArgumentError) do
        AutoClaude::Process::Manager.new(
          directory: "/nonexistent/path",
          claude_options: []
        )
      end
    end

    def test_manager_validates_claude_options
      assert_raises(ArgumentError) do
        AutoClaude::Process::Manager.new(
          directory: Dir.pwd,
          claude_options: ["--verbose"] # Forbidden option
        )
      end

      assert_raises(ArgumentError) do
        AutoClaude::Process::Manager.new(
          directory: Dir.pwd,
          claude_options: ["--output-format", "json"]
        )
      end
    end

    def test_manager_builds_correct_command
      manager = AutoClaude::Process::Manager.new(
        directory: Dir.pwd,
        claude_options: ["--model", "opus"]
      )

      command = manager.send(:build_command)

      assert_equal ["claude", "-p", "--verbose", "--output-format", "stream-json", "--model", "opus"], command
    end

    def test_manager_execute_with_mock_process
      messages_received = []

      manager = AutoClaude::Process::Manager.new(
        directory: Dir.pwd,
        claude_options: []
      )

      mock_output = <<~JSON
        {"type": "assistant", "message": {"content": [{"type": "text", "text": "Processing"}]}}
        {"type": "result", "subtype": "success", "result": "Complete", "success": true}
      JSON

      Open3.stub :popen3, create_mock_popen(mock_output, 0) do
        manager.execute("test prompt", stream_handler: lambda { |msg|
          messages_received << msg
        })
      end

      assert_equal 2, messages_received.count
      assert_equal "Processing", messages_received[0].text
      assert_equal "Complete", messages_received[1].content
    end

    def test_manager_execute_handles_process_failure
      manager = AutoClaude::Process::Manager.new(
        directory: Dir.pwd,
        claude_options: []
      )

      Open3.stub :popen3, create_mock_popen("", 1, "Command failed") do
        error = assert_raises(RuntimeError) do
          manager.execute("test", stream_handler: ->(msg) {})
        end

        assert_match(/exit code 1/, error.message)
        assert_match(/Command failed/, error.message)
      end
    end

    private

    def create_mock_popen(stdout_content, exit_code = 0, stderr_content = "")
      lambda { |_script_path, &block|
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
