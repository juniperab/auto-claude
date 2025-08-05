require "test_helper"

class AutoClaude::ColorPrinterTest < Minitest::Test
  def setup
    @original_stderr = $stderr
    @stderr_output = StringIO.new
    $stderr = @stderr_output
  end
  
  def teardown
    $stderr = @original_stderr
    AutoClaude::ColorPrinter.stderr_callback = nil
    AutoClaude::ColorPrinter.close_log_file
  end

  def test_print_message_without_callback
    AutoClaude::ColorPrinter.print_message("Hello World", color: :cyan)
    
    output = @stderr_output.string
    assert_match(/Hello World/, output)
    assert_match(/\e\[/, output) # Contains ANSI color codes
  end

  def test_print_message_with_callback
    callback_calls = []
    
    AutoClaude::ColorPrinter.stderr_callback = -> (msg, type, color) {
      callback_calls << { message: msg, type: type, color: color }
    }
    
    AutoClaude::ColorPrinter.print_message("Test Message", color: :blue)
    
    assert_equal 1, callback_calls.length
    assert_equal "  Test Message\n", callback_calls[0][:message]
    assert_equal :message, callback_calls[0][:type]
    assert_equal :blue, callback_calls[0][:color]
  end

  def test_print_stat_with_callback
    callback_calls = []
    
    AutoClaude::ColorPrinter.stderr_callback = -> (msg, type, color) {
      callback_calls << { message: msg, type: type, color: color }
    }
    
    AutoClaude::ColorPrinter.print_stat("CPU: 50%")
    
    assert_equal 1, callback_calls.length
    assert_equal "  CPU: 50%\n", callback_calls[0][:message]
    assert_equal :stat, callback_calls[0][:type]
    assert_equal :dark_gray, callback_calls[0][:color]
  end

  def test_callback_receives_correct_colors
    callback_calls = []
    
    AutoClaude::ColorPrinter.stderr_callback = -> (msg, type, color) {
      callback_calls << color
    }
    
    AutoClaude::ColorPrinter.print_message("Red", color: :red)
    AutoClaude::ColorPrinter.print_message("Blue", color: :blue)
    AutoClaude::ColorPrinter.print_message("Cyan", color: :cyan)
    
    assert_equal [:red, :blue, :cyan], callback_calls
  end

  def test_multiline_message_with_callback
    callback_calls = []
    
    AutoClaude::ColorPrinter.stderr_callback = -> (msg, type, color) {
      callback_calls << msg
    }
    
    AutoClaude::ColorPrinter.print_message("First\nSecond\nThird", color: :cyan)
    
    assert_equal 3, callback_calls.length
    assert_equal "  First\n", callback_calls[0]
    assert_equal "  Second\n", callback_calls[1]
    assert_equal "  Third\n", callback_calls[2]
  end

  def test_callback_with_truncation_notice
    callback_calls = []
    
    AutoClaude::ColorPrinter.stderr_callback = -> (msg, type, color) {
      callback_calls << { message: msg, color: color }
    }
    
    # Create message with more lines than max_lines
    long_message = (1..10).map { |i| "Line #{i}" }.join("\n")
    AutoClaude::ColorPrinter.print_message(long_message, color: :cyan, max_lines: 3)
    
    # Should get 3 lines + truncation notice
    assert_equal 4, callback_calls.length
    
    # Check truncation notice
    last_call = callback_calls.last
    assert_match(/\+ 7 lines not shown/, last_call[:message])
    assert_equal :light_gray, last_call[:color]
  end

  def test_callback_nil_safe
    # Should not raise error when callback is nil
    AutoClaude::ColorPrinter.stderr_callback = nil
    
    # Just verify no exception is raised
    AutoClaude::ColorPrinter.print_message("Test", color: :cyan)
    AutoClaude::ColorPrinter.print_stat("Stat")
    
    # If we got here without exception, test passes
    assert true
  end

  def test_log_file_with_callback
    Tempfile.create("test_log") do |tmpfile|
      callback_calls = []
      
      AutoClaude::ColorPrinter.set_log_file(tmpfile.path)
      AutoClaude::ColorPrinter.stderr_callback = -> (msg, type, color) {
        callback_calls << msg
      }
      
      AutoClaude::ColorPrinter.print_message("Logged Message", color: :cyan)
      AutoClaude::ColorPrinter.close_log_file
      
      # Check callback was called
      assert_equal 1, callback_calls.length
      assert_equal "  Logged Message\n", callback_calls[0]
      
      # Check log file content (should not have ANSI codes)
      log_content = File.read(tmpfile.path)
      assert_match(/Logged Message/, log_content)
      refute_match(/\e\[/, log_content) # No ANSI codes in log
    end
  end

  def test_callback_persistence_across_multiple_calls
    call_count = 0
    
    AutoClaude::ColorPrinter.stderr_callback = -> (msg, type, color) {
      call_count += 1
    }
    
    5.times do |i|
      AutoClaude::ColorPrinter.print_message("Message #{i}", color: :cyan)
    end
    
    assert_equal 5, call_count
  end

  def test_callback_with_empty_message
    callback_calls = []
    
    AutoClaude::ColorPrinter.stderr_callback = -> (msg, type, color) {
      callback_calls << msg
    }
    
    AutoClaude::ColorPrinter.print_message("", color: :cyan)
    AutoClaude::ColorPrinter.print_message(nil, color: :cyan)
    
    # Empty string creates empty message, nil is ignored
    assert_equal 0, callback_calls.length
  end

  def test_colors_hash_integrity
    # Verify all expected colors exist
    expected_colors = [:blue, :cyan, :light_gray, :dark_gray, :red, :white]
    
    expected_colors.each do |color|
      assert AutoClaude::ColorPrinter::COLORS.key?(color), "Missing color: #{color}"
      assert AutoClaude::ColorPrinter::COLORS[color].key?(:regular), "Missing regular for #{color}"
      assert AutoClaude::ColorPrinter::COLORS[color].key?(:bold), "Missing bold for #{color}"
    end
  end
end