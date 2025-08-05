require "test_helper"

class AutoClaude::StreamingTest < Minitest::Test
  def setup
    @captured_messages = []
    @mock_runner = Minitest::Mock.new
  end
  
  def teardown
    AutoClaude::ColorPrinter.stderr_callback = nil
    AutoClaude::ColorPrinter.close_log_file
  end

  def test_stderr_callback_receives_messages
    callback_calls = []
    
    # Mock runner that triggers ColorPrinter messages
    runner = Object.new
    def runner.run(input)
      AutoClaude::ColorPrinter.print_message("Processing request...", color: :cyan)
      AutoClaude::ColorPrinter.print_stat("Time: 1.2s")
      AutoClaude::ColorPrinter.print_message("Complete!", color: :blue)
      "Result"
    end
    
    AutoClaude::ClaudeRunner.stub :new, runner do
      result = AutoClaude::App.run(
        "Test",
        stderr_callback: -> (msg, type, color) {
          callback_calls << { message: msg, type: type, color: color }
        }
      )
      
      assert_equal "Result", result
      assert_equal 3, callback_calls.length
      
      # Check first message
      assert_equal "  Processing request...\n", callback_calls[0][:message]
      assert_equal :message, callback_calls[0][:type]
      assert_equal :cyan, callback_calls[0][:color]
      
      # Check stat message
      assert_equal "  Time: 1.2s\n", callback_calls[1][:message]
      assert_equal :stat, callback_calls[1][:type]
      assert_equal :dark_gray, callback_calls[1][:color]
      
      # Check last message
      assert_equal "  Complete!\n", callback_calls[2][:message]
      assert_equal :message, callback_calls[2][:type]
      assert_equal :blue, callback_calls[2][:color]
    end
  end

  def test_stderr_callback_with_multiline_messages
    callback_calls = []
    
    runner = Object.new
    def runner.run(input)
      AutoClaude::ColorPrinter.print_message("Line 1\nLine 2\nLine 3", color: :cyan)
      "Result"
    end
    
    AutoClaude::ClaudeRunner.stub :new, runner do
      AutoClaude::App.run(
        "Test",
        stderr_callback: -> (msg, type, color) {
          callback_calls << msg
        }
      )
      
      # Should receive each line separately
      assert_equal 3, callback_calls.length
      assert_equal "  Line 1\n", callback_calls[0]
      assert_equal "  Line 2\n", callback_calls[1]
      assert_equal "  Line 3\n", callback_calls[2]
    end
  end

  def test_stderr_callback_with_truncation
    callback_calls = []
    
    runner = Object.new
    def runner.run(input)
      # Create a message with many lines
      long_message = (1..10).map { |i| "Line #{i}" }.join("\n")
      AutoClaude::ColorPrinter.print_message(long_message, color: :cyan, max_lines: 5)
      "Result"
    end
    
    AutoClaude::ClaudeRunner.stub :new, runner do
      AutoClaude::App.run(
        "Test",
        stderr_callback: -> (msg, type, color) {
          callback_calls << { message: msg, color: color }
        }
      )
      
      # Should receive 5 lines + truncation notice
      assert_equal 6, callback_calls.length
      
      # Check truncation notice
      last_call = callback_calls.last
      assert_match(/\+ 5 lines not shown/, last_call[:message])
      assert_equal :light_gray, last_call[:color]
    end
  end

  def test_stderr_callback_disabled_truncation
    callback_calls = []
    
    runner = Object.new
    def runner.run(input)
      # Create a message with many lines
      long_message = (1..10).map { |i| "Line #{i}" }.join("\n")
      AutoClaude::ColorPrinter.print_message(long_message, color: :cyan, disable_truncation: true)
      "Result"
    end
    
    AutoClaude::ClaudeRunner.stub :new, runner do
      AutoClaude::App.run(
        "Test",
        stderr_callback: -> (msg, type, color) {
          callback_calls << msg
        }
      )
      
      # Should receive all 10 lines without truncation
      assert_equal 10, callback_calls.length
      assert_equal "  Line 10\n", callback_calls.last
    end
  end

  def test_stderr_callback_filters_by_type
    stat_messages = []
    regular_messages = []
    
    runner = Object.new
    def runner.run(input)
      AutoClaude::ColorPrinter.print_message("Processing...", color: :cyan)
      AutoClaude::ColorPrinter.print_stat("Stats: 100%")
      AutoClaude::ColorPrinter.print_message("Done", color: :blue)
      AutoClaude::ColorPrinter.print_stat("Time: 5s")
      "Result"
    end
    
    AutoClaude::ClaudeRunner.stub :new, runner do
      AutoClaude::App.run(
        "Test",
        stderr_callback: -> (msg, type, color) {
          if type == :stat
            stat_messages << msg.strip
          else
            regular_messages << msg.strip
          end
        }
      )
      
      assert_equal 2, stat_messages.length
      assert_equal 2, regular_messages.length
      
      assert_includes stat_messages, "Stats: 100%"
      assert_includes stat_messages, "Time: 5s"
      assert_includes regular_messages, "Processing..."
      assert_includes regular_messages, "Done"
    end
  end

  def test_stderr_callback_continues_on_exception
    callback_calls = []
    error_count = 0
    
    runner = Object.new
    def runner.run(input)
      AutoClaude::ColorPrinter.print_message("Message 1", color: :cyan)
      AutoClaude::ColorPrinter.print_message("Message 2", color: :cyan)
      AutoClaude::ColorPrinter.print_message("Message 3", color: :cyan)
      "Result"
    end
    
    AutoClaude::ClaudeRunner.stub :new, runner do
      AutoClaude::App.run(
        "Test",
        stderr_callback: -> (msg, type, color) {
          callback_calls << msg
          # Simulate error on second message
          if callback_calls.length == 2
            error_count += 1
            raise "Callback error"
          end
        }
      )
      
      # Should still receive all messages despite callback error
      assert_equal 3, callback_calls.length
      assert_equal 1, error_count
    end
  end

  def test_stderr_callback_with_retry_messages
    callback_calls = []
    
    # First attempt fails
    error_runner = Object.new
    def error_runner.run(input)
      raise "Network error"
    end
    def error_runner.instance_variable_get(var)
      {"session_id" => "xyz789"} if var == :@result_metadata
    end
    
    # Second attempt succeeds
    success_runner = Minitest::Mock.new
    success_runner.expect :run, "Success", ["Test"]
    
    call_count = 0
    AutoClaude::ClaudeRunner.stub :new, -> (opts) {
      call_count += 1
      call_count == 1 ? error_runner : success_runner
    } do
      AutoClaude::App.run(
        "Test", 
        retry_on_error: true,
        stderr_callback: -> (msg, type, color) {
          callback_calls << { message: msg, type: type, color: color }
        }
      )
      
      # Find retry and error messages
      retry_msg = callback_calls.find { |c| c[:message].include?("Retrying with --resume") }
      error_msg = callback_calls.find { |c| c[:message].include?("Error occurred") }
      
      assert retry_msg, "Should have retry message"
      assert_equal :message, retry_msg[:type]
      assert_equal :cyan, retry_msg[:color]
      
      assert error_msg, "Should have error message"
      assert_equal :message, error_msg[:type]
      assert_equal :red, error_msg[:color]
    end
    
    success_runner.verify
  end
end