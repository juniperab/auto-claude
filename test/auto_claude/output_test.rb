require "test_helper"
require "auto_claude/output/memory"
require "auto_claude/output/terminal"
require "auto_claude/output/file"
require "auto_claude/output/formatter"
require "auto_claude/messages/base"
require "tempfile"

class AutoClaude::OutputTest < Minitest::Test
  def test_memory_output_stores_messages
    output = AutoClaude::Output::Memory.new
    
    message = create_text_message("Hello")
    output.write_message(message)
    output.write_user_message("Test prompt")
    output.write_stat("Cost", "$0.001")
    output.write_error("Test error")
    output.write_info("Test info")
    output.write_divider
    
    assert_equal 1, output.messages.count
    assert_equal ["Test prompt"], output.user_messages
    assert_equal "$0.001", output.stats["Cost"]
    assert_equal ["Test error"], output.errors
    assert_equal ["Test info"], output.info
  end

  def test_memory_output_clear
    output = AutoClaude::Output::Memory.new
    
    output.write_message(create_text_message("Hello"))
    output.write_stat("Test", "Value")
    output.clear
    
    assert_empty output.messages
    assert_empty output.stats
  end

  def test_terminal_output_writes_to_stream
    stream = StringIO.new
    output = AutoClaude::Output::Terminal.new(stream: stream, color: false)
    
    output.write_message(create_text_message("Hello world"))
    output.write_divider
    
    stream_content = stream.string
    assert_match(/Hello world/, stream_content)
    assert_match(/---/, stream_content)
  end

  def test_terminal_output_with_colors
    stream = StringIO.new
    output = AutoClaude::Output::Terminal.new(stream: stream, color: true)
    
    output.write_error("Error message")
    
    stream_content = stream.string
    assert_match(/\e\[31m/, stream_content) # Red color
    assert_match(/Error message/, stream_content)
    assert_match(/\e\[0m/, stream_content) # Reset
  end

  def test_file_output_writes_to_file
    Tempfile.create("test_output") do |tmpfile|
      output = AutoClaude::Output::File.new(tmpfile.path)
      
      output.write_message(create_text_message("File test"))
      output.write_stat("Session", "123")
      output.close
      
      content = File.read(tmpfile.path)
      assert_match(/File test/, content)
      assert_match(/Session: 123/, content)
    end
  end

  def test_file_output_invalid_path
    assert_raises(ArgumentError) do
      AutoClaude::Output::File.new("/invalid/path/file.log")
    end
  end

  def test_multiplexer_output
    memory1 = AutoClaude::Output::Memory.new
    memory2 = AutoClaude::Output::Memory.new
    
    multiplexer = AutoClaude::Output::Multiplexer.new([memory1, memory2])
    
    message = create_text_message("Multi test")
    multiplexer.write_message(message)
    multiplexer.write_stat("Test", "Value")
    
    assert_equal 1, memory1.messages.count
    assert_equal 1, memory2.messages.count
    assert_equal "Value", memory1.stats["Test"]
    assert_equal "Value", memory2.stats["Test"]
  end

  def test_formatter_text_truncation
    formatter = AutoClaude::Output::Formatter.new(truncate: true, max_lines: 3)
    
    message = create_text_message("Line 1\nLine 2\nLine 3\nLine 4\nLine 5")
    formatted = formatter.format_message(message)
    
    assert_match(/Line 1/, formatted)
    assert_match(/Line 3/, formatted)
    refute_match(/Line 4/, formatted)
    assert_match(/\+ 2 more lines/, formatted)
  end

  def test_formatter_tool_use
    formatter = AutoClaude::Output::Formatter.new
    
    bash_msg = create_tool_use_message("Bash", {"command" => "pwd"})
    formatted = formatter.format_message(bash_msg)
    assert_equal '🖥️ Running: pwd', formatted
    
    read_msg = create_tool_use_message("Read", {"file_path" => "/tmp/test.txt"})
    formatted = formatter.format_message(read_msg)
    assert_equal '👀 Reading /tmp/test.txt', formatted
  end

  def test_formatter_todo_write_not_truncated
    formatter = AutoClaude::Output::Formatter.new(truncate: true, max_lines: 2)
    
    todos = (1..10).map { |i| {"content" => "Task #{i}", "status" => "pending"} }
    todo_msg = create_tool_use_message("TodoWrite", {"todos" => todos})
    
    formatted = formatter.format_message(todo_msg)
    
    # The new formatter shows a summary and up to 3 tasks
    assert_match(/📝 Todo: 10 tasks/, formatted)
    assert_match(/Task 1/, formatted)
    # Task 10 won't be shown as it only shows first 3 pending tasks
    refute_match(/Task 10/, formatted)
    refute_match(/not shown/, formatted)
  end

  private

  def create_text_message(text)
    json = {
      "type" => "assistant",
      "message" => {
        "content" => [{"type" => "text", "text" => text}]
      }
    }
    AutoClaude::Messages::Base.from_json(json)
  end

  def create_tool_use_message(tool_name, input)
    json = {
      "type" => "assistant",
      "message" => {
        "content" => [
          {"type" => "tool_use", "name" => tool_name, "input" => input}
        ]
      }
    }
    AutoClaude::Messages::Base.from_json(json)
  end
end