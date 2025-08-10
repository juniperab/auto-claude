require "test_helper"

class AutoClaude::MessageFormatterTest < Minitest::Test
  def setup
    @original_stderr = $stderr
    @stderr_output = StringIO.new
    $stderr = @stderr_output
  end
  
  def teardown
    $stderr = @original_stderr
    AutoClaude::ColorPrinter.close_log_file
  end

  # Text message tests
  
  def test_format_text_message
    message = {
      "type" => "text",
      "text" => "Hello, world!"
    }
    
    json = {
      "message" => {
        "content" => [message]
      }
    }
    
    AutoClaude::MessageFormatter.format_and_print_messages(json)
    
    output = @stderr_output.string
    assert_match(/→\s+Hello, world!/, output)
  end

  def test_format_multiline_text_message
    message = {
      "type" => "text",
      "text" => "Line 1\nLine 2\nLine 3"
    }
    
    json = {
      "message" => {
        "content" => [message]
      }
    }
    
    AutoClaude::MessageFormatter.format_and_print_messages(json)
    
    output = @stderr_output.string
    assert_match(/→\s+Line 1/, output)
    assert_match(/\s+Line 2/, output)
    assert_match(/\s+Line 3/, output)
  end

  def test_format_empty_text_message
    message = {
      "type" => "text",
      "text" => ""
    }
    
    json = {
      "message" => {
        "content" => [message]
      }
    }
    
    AutoClaude::MessageFormatter.format_and_print_messages(json)
    
    output = @stderr_output.string
    assert_match(/→/, output)
  end

  def test_format_nil_text_message
    message = {
      "type" => "text",
      "text" => nil
    }
    
    json = {
      "message" => {
        "content" => [message]
      }
    }
    
    AutoClaude::MessageFormatter.format_and_print_messages(json)
    
    output = @stderr_output.string
    assert_match(/→/, output)
  end

  # Tool use message tests
  
  def test_format_bash_tool_use
    message = {
      "type" => "tool_use",
      "name" => "Bash",
      "input" => {
        "command" => "ls -la",
        "description" => "List files"
      }
    }
    
    json = {
      "message" => {
        "content" => [message]
      }
    }
    
    AutoClaude::MessageFormatter.format_and_print_messages(json)
    
    output = @stderr_output.string
    assert_match(/→ Bash\("ls -la"\)/, output)
  end

  def test_format_read_tool_use
    message = {
      "type" => "tool_use",
      "name" => "Read",
      "input" => {
        "file_path" => "/tmp/test.txt",
        "description" => "Read test file"
      }
    }
    
    json = {
      "message" => {
        "content" => [message]
      }
    }
    
    AutoClaude::MessageFormatter.format_and_print_messages(json)
    
    output = @stderr_output.string
    assert_match(/→ Read\("\/tmp\/test.txt"\)/, output)
  end

  def test_format_edit_tool_use
    message = {
      "type" => "tool_use",
      "name" => "Edit",
      "input" => {
        "file_path" => "/tmp/test.txt",
        "old_string" => "old content",
        "new_string" => "new content",
        "description" => "Update file"
      }
    }
    
    json = {
      "message" => {
        "content" => [message]
      }
    }
    
    AutoClaude::MessageFormatter.format_and_print_messages(json)
    
    output = @stderr_output.string
    assert_match(/→ Edit\("\/tmp\/test.txt"\)/, output)
    # Should exclude old_string and new_string from output
    refute_match(/old content/, output)
    refute_match(/new content/, output)
  end

  def test_format_task_tool_use
    message = {
      "type" => "tool_use",
      "name" => "Task",
      "input" => {
        "prompt" => "This is a task prompt\nwith multiple lines",
        "description" => "Task description"
      }
    }
    
    json = {
      "message" => {
        "content" => [message]
      }
    }
    
    AutoClaude::MessageFormatter.format_and_print_messages(json)
    
    output = @stderr_output.string
    assert_match(/→ Task/, output)
    assert_match(/This is a task prompt/, output)
    assert_match(/with multiple lines/, output)
  end

  def test_format_task_tool_use_without_prompt
    message = {
      "type" => "tool_use",
      "name" => "Task",
      "input" => {
        "description" => "Task without prompt"
      }
    }
    
    json = {
      "message" => {
        "content" => [message]
      }
    }
    
    AutoClaude::MessageFormatter.format_and_print_messages(json)
    
    output = @stderr_output.string
    assert_match(/→ Task\(\)/, output)
  end

  def test_format_todo_write_tool_use
    message = {
      "type" => "tool_use",
      "name" => "TodoWrite",
      "input" => {
        "todos" => [
          {"id" => "1", "content" => "First task", "status" => "pending"},
          {"id" => "2", "content" => "Second task", "status" => "in_progress"},
          {"id" => "3", "content" => "Third task", "status" => "completed"}
        ]
      }
    }
    
    json = {
      "message" => {
        "content" => [message]
      }
    }
    
    # TodoWrite should not have truncation
    AutoClaude::MessageFormatter.format_and_print_messages(json)
    
    output = @stderr_output.string
    assert_match(/→ TodoWrite/, output)
    assert_match(/1\. \[ \] First task/, output)
    assert_match(/2\. \[-\] Second task/, output)
    assert_match(/3\. \[x\] Third task/, output)
  end

  def test_format_todo_write_with_unknown_status
    message = {
      "type" => "tool_use",
      "name" => "TodoWrite",
      "input" => {
        "todos" => [
          {"id" => "1", "content" => "Unknown status task", "status" => "unknown"}
        ]
      }
    }
    
    json = {
      "message" => {
        "content" => [message]
      }
    }
    
    AutoClaude::MessageFormatter.format_and_print_messages(json)
    
    output = @stderr_output.string
    assert_match(/1\. \[\?\] Unknown status task/, output)
  end

  def test_format_unknown_tool_use
    message = {
      "type" => "tool_use",
      "name" => "UnknownTool",
      "input" => {
        "param1" => "value1",
        "param2" => "value2"
      }
    }
    
    json = {
      "message" => {
        "content" => [message]
      }
    }
    
    AutoClaude::MessageFormatter.format_and_print_messages(json)
    
    output = @stderr_output.string
    assert_match(/→ UnknownTool/, output)
    # Should format as YAML for unknown tools
    assert_match(/param1/, output)
    assert_match(/value1/, output)
  end

  # Tool result messages
  
  def test_tool_result_messages_are_ignored
    message = {
      "type" => "tool_result",
      "content" => "Some result"
    }
    
    json = {
      "message" => {
        "content" => [message]
      }
    }
    
    AutoClaude::MessageFormatter.format_and_print_messages(json)
    
    output = @stderr_output.string
    # Tool results should not produce any output
    assert_equal "", output.gsub(/\e\[[0-9;]*m/, '').strip
  end

  # Multiple messages
  
  def test_format_multiple_messages
    messages = [
      {"type" => "text", "text" => "First message"},
      {"type" => "tool_use", "name" => "Bash", "input" => {"command" => "pwd"}},
      {"type" => "text", "text" => "Second message"}
    ]
    
    json = {
      "message" => {
        "content" => messages
      }
    }
    
    AutoClaude::MessageFormatter.format_and_print_messages(json)
    
    output = @stderr_output.string
    assert_match(/First message/, output)
    assert_match(/Bash\("pwd"\)/, output)
    assert_match(/Second message/, output)
  end

  # Edge cases
  
  def test_format_with_missing_content
    json = {
      "message" => {}
    }
    
    # Should not raise error
    AutoClaude::MessageFormatter.format_and_print_messages(json)
    
    output = @stderr_output.string
    assert_equal "", output.gsub(/\e\[[0-9;]*m/, '').strip
  end

  def test_format_with_nil_content
    json = {
      "message" => {
        "content" => nil
      }
    }
    
    # Should not raise error
    AutoClaude::MessageFormatter.format_and_print_messages(json)
    
    output = @stderr_output.string
    assert_equal "", output.gsub(/\e\[[0-9;]*m/, '').strip
  end

  def test_format_with_empty_array
    json = {
      "message" => {
        "content" => []
      }
    }
    
    # Should not raise error
    AutoClaude::MessageFormatter.format_and_print_messages(json)
    
    output = @stderr_output.string
    assert_equal "", output.gsub(/\e\[[0-9;]*m/, '').strip
  end

  def test_format_unknown_message_type
    message = {
      "type" => "unknown_type",
      "data" => "some data"
    }
    
    json = {
      "message" => {
        "content" => [message]
      }
    }
    
    AutoClaude::MessageFormatter.format_and_print_messages(json)
    
    output = @stderr_output.string
    # Should output as YAML excluding id
    assert_match(/type: unknown_type/, output)
    assert_match(/data: some data/, output)
  end

  def test_format_with_multiple_argument_tool
    message = {
      "type" => "tool_use",
      "name" => "CustomTool",
      "input" => {
        "arg1" => "value1",
        "arg2" => "value2",
        "arg3" => "value3"
      }
    }
    
    json = {
      "message" => {
        "content" => [message]
      }
    }
    
    AutoClaude::MessageFormatter.format_and_print_messages(json)
    
    output = @stderr_output.string
    assert_match(/→ CustomTool/, output)
    # Multiple arguments should be formatted
    assert_match(/arg1/, output)
    assert_match(/value1/, output)
  end

  def test_format_tool_with_nil_input
    message = {
      "type" => "tool_use",
      "name" => "SomeTool",
      "input" => nil
    }
    
    json = {
      "message" => {
        "content" => [message]
      }
    }
    
    # Should not crash
    AutoClaude::MessageFormatter.format_and_print_messages(json)
    
    output = @stderr_output.string
    assert_match(/→ SomeTool/, output)
  end

  def test_format_tool_with_empty_input
    message = {
      "type" => "tool_use",
      "name" => "EmptyTool",
      "input" => {}
    }
    
    json = {
      "message" => {
        "content" => [message]
      }
    }
    
    AutoClaude::MessageFormatter.format_and_print_messages(json)
    
    output = @stderr_output.string
    # Unknown tools with empty input show the empty hash
    assert_match(/→ EmptyTool/, output)
    assert_match(/\{\}/, output)
  end
end