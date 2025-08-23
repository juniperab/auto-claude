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

    def test_run_creates_session
      client = AutoClaude::Client.new(output: @memory_output)

      # Mock the process execution
      AutoClaude::Process::Manager.stub :new, MockProcessManager.new do
        session = client.run("test prompt")

        assert_kind_of AutoClaude::Session, session
        assert_includes client.sessions, session
        assert_equal 1, client.sessions.count
      end
    end

    def test_run_with_block_callback
      client = AutoClaude::Client.new(output: @memory_output)
      messages_received = []

      mock_manager = MockProcessManager.new
      mock_manager.add_message(create_message("assistant", "text", "Hello"))
      mock_manager.add_result("Done")

      AutoClaude::Process::Manager.stub :new, mock_manager do
        client.run("test") do |message|
          messages_received << message
        end

        assert_equal 2, messages_received.count
      end
    end

    def test_run_async_returns_thread
      client = AutoClaude::Client.new(output: @memory_output)

      AutoClaude::Process::Manager.stub :new, MockProcessManager.new do
        thread = client.run_async("test prompt")

        assert_kind_of Thread, thread
        session = thread.value

        assert_kind_of AutoClaude::Session, session
      end
    end

    def test_multiple_concurrent_sessions
      client = AutoClaude::Client.new(output: @memory_output)

      AutoClaude::Process::Manager.stub :new, MockProcessManager.new do
        threads = 5.times.map do |i|
          client.run_async("prompt #{i}")
        end

        sessions = threads.map(&:value)

        assert_equal 5, sessions.count
        assert_equal 5, client.sessions.count
      end
    end

    private

    class MockProcessManager
      def initialize
        @messages = []
      end

      def add_message(msg)
        @messages << msg
      end

      def add_result(content)
        @messages << create_result_message(content)
      end

      def execute(_prompt, stream_handler:)
        @messages.each { |msg| stream_handler.call(msg) }
      end

      private

      def create_result_message(content)
        json = {
          "type" => "result",
          "subtype" => "success",
          "result" => content,
          "success" => true
        }
        AutoClaude::Messages::Base.from_json(json)
      end
    end

    def create_message(type, content_type, text)
      json = {
        "type" => type,
        "message" => {
          "content" => [
            { "type" => content_type, "text" => text }
          ]
        }
      }
      AutoClaude::Messages::Base.from_json(json)
    end
  end
end
