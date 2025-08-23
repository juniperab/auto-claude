require 'test_helper'
require 'auto_claude/output/formatter'
require 'auto_claude/messages/base'

module AutoClaude
  module Output
    class FormatterResultTest < Minitest::Test
      def setup
        @formatter = Formatter.new(color: false, truncate: false)
      end
      
      def test_empty_result
        msg = create_tool_result("")
        output = @formatter.format_message(msg)
        
        assert_equal "   Result: (empty)", output
      end
      
      def test_short_single_line_result
        msg = create_tool_result("Success")
        output = @formatter.format_message(msg)
        
        assert_equal "   Result: Success", output
      end
      
      def test_long_single_line_result
        long_text = "x" * 150
        msg = create_tool_result(long_text)
        output = @formatter.format_message(msg)
        lines = output.split("\n")
        
        assert_match(/   Result: \[1 lines, 0\.1KB\]/, lines[0])
        assert_equal "        #{long_text}", lines[1]
        assert_equal 2, lines.length
      end
      
      def test_multiline_result_under_5_lines
        content = "Line 1\nLine 2\nLine 3"
        msg = create_tool_result(content)
        output = @formatter.format_message(msg)
        lines = output.split("\n")
        
        assert_match(/   Result: \[3 lines, 0\.0KB\]/, lines[0])
        assert_equal "        Line 1", lines[1]
        assert_equal "        Line 2", lines[2]
        assert_equal "        Line 3", lines[3]
        assert_equal 4, lines.length # No ellipsis
      end
      
      def test_multiline_result_exactly_5_lines
        content = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5"
        msg = create_tool_result(content)
        output = @formatter.format_message(msg)
        lines = output.split("\n")
        
        assert_match(/   Result: \[5 lines, 0\.0KB\]/, lines[0])
        assert_equal "        Line 1", lines[1]
        assert_equal "        Line 5", lines[5]
        assert_equal 6, lines.length # No ellipsis
      end
      
      def test_multiline_result_over_5_lines
        content = (1..10).map { |i| "Line #{i}" }.join("\n")
        msg = create_tool_result(content)
        output = @formatter.format_message(msg)
        lines = output.split("\n")
        
        assert_match(/   Result: \[10 lines, 0\.1KB\]/, lines[0])
        assert_equal "        Line 1", lines[1]
        assert_equal "        Line 2", lines[2]
        assert_equal "        Line 3", lines[3]
        assert_equal "        Line 4", lines[4]
        assert_equal "        Line 5", lines[5]
        assert_equal "        ...", lines[6]
        assert_equal 7, lines.length
      end
      
      def test_large_result_with_size
        # Create a 2KB result
        line = "x" * 100 + "\n"
        content = line * 21 # ~2.1KB
        msg = create_tool_result(content)
        output = @formatter.format_message(msg)
        lines = output.split("\n")
        
        assert_match(/   Result: \[21 lines, 2\.1KB\]/, lines[0])
        assert_match(/^        x{100}$/, lines[1])
        assert_equal "        ...", lines[6]
      end
      
      def test_result_with_empty_lines
        content = "Line 1\n\nLine 3\n\n\nLine 6"
        msg = create_tool_result(content)
        output = @formatter.format_message(msg)
        lines = output.split("\n")
        
        assert_match(/   Result: \[6 lines, 0\.0KB\]/, lines[0])
        assert_equal "        Line 1", lines[1]
        assert_equal "        ", lines[2] # Empty line preserved
        assert_equal "        Line 3", lines[3]
        assert_equal "        ", lines[4]
        assert_equal "        ", lines[5]
        assert_equal "        ...", lines[6]
      end
      
      def test_error_result_still_uses_old_format
        msg = create_tool_result("Error occurred", is_error: true)
        output = @formatter.format_message(msg)
        
        assert_match(/⚠️ Error: Error occurred/, output)
        refute_match(/\[.*lines.*KB\]/, output)
      end
      
      def test_filtered_result_returns_nil
        msg = create_tool_result("Todos have been modified successfully")
        output = @formatter.format_message(msg)
        
        assert_nil output
      end
      
      def test_result_with_trailing_newlines
        content = "Line 1\nLine 2\n\n"
        msg = create_tool_result(content)
        output = @formatter.format_message(msg)
        lines = output.split("\n")
        
        assert_match(/   Result: \[3 lines, 0\.0KB\]/, lines[0])
        assert_equal "        Line 1", lines[1]
        assert_equal "        Line 2", lines[2]
        assert_equal "        ", lines[3]
      end
      
      def test_very_long_lines_in_preview
        long_line = "x" * 200
        content = "#{long_line}\nShort line\n#{long_line}"
        msg = create_tool_result(content)
        output = @formatter.format_message(msg)
        lines = output.split("\n")
        
        assert_match(/   Result: \[3 lines, 0\.4KB\]/, lines[0])
        assert_equal "        #{long_line}", lines[1]
        assert_equal "        Short line", lines[2]
        assert_equal "        #{long_line}", lines[3]
      end
      
      private
      
      def create_tool_result(content, is_error: false)
        json = {
          "type" => "user",
          "message" => {
            "content" => [
              {
                "type" => "tool_result",
                "content" => content,
                "is_error" => is_error
              }
            ]
          }
        }
        Messages::Base.from_json(json)
      end
    end
  end
end