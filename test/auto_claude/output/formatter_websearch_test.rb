require 'test_helper'
require 'auto_claude/output/formatter'
require 'auto_claude/messages/base'

module AutoClaude
  module Output
    class FormatterWebSearchTest < Minitest::Test
      def setup
        @formatter = Formatter.new(color: false, truncate: false)
      end
      
      def test_websearch_result_with_links
        # Simulate a WebSearch result like the one that caused the error
        content = <<~CONTENT
          Web search results for query: "God Object anti-pattern code smell refactoring"
          
          I'll search for information about the God Object anti-pattern, which is an important code smell and refactoring topic in software engineering.
          
          Links: [{"title":"How to refactor the God object class antipattern | TheServerSide","url":"https://www.theserverside.com/tip/How-to-refactor-the-God-object-antipattern"},{"title":"God Object - A Code Smell","url":"https://www.c-sharpcorner.com/article/god-object-a-code-smell/"}]
        CONTENT
        
        msg = create_tool_result(content)
        output = @formatter.format_message(msg)
        
        refute_nil output
        lines = output.split("\n")
        
        assert_match(/📋 Result: \[5 lines, 0\.\dKB\]/, lines[0])
        assert_match(/Web search results/, lines[1])
        assert_equal 7, lines.length # Header + 5 preview lines + ellipsis
      end
      
      def test_nil_content_in_result
        msg = create_tool_result(nil)
        output = @formatter.format_message(msg)
        
        assert_equal "📋 Result: (empty)", output
      end
      
      def test_result_with_nil_lines_edge_case
        # Test with content that might cause lines to be nil
        msg = create_tool_result("")
        output = @formatter.format_message(msg)
        
        assert_equal "📋 Result: (empty)", output
      end
      
      def test_result_with_special_characters
        content = "Line with special chars: \u0000\u0001\u0002"
        msg = create_tool_result(content)
        output = @formatter.format_message(msg)
        
        refute_nil output
        assert_match(/📋 Result:/, output)
      end
      
      def test_truncate_text_with_nil
        truncated = @formatter.send(:truncate_text, nil)
        assert_equal "", truncated
      end
      
      def test_truncate_text_with_empty_string
        truncated = @formatter.send(:truncate_text, "")
        assert_equal "", truncated
      end
      
      def test_format_result_with_preview_nil_input
        result = @formatter.send(:format_result_with_preview, nil)
        assert_equal "📋 Result: (empty)", result
      end
      
      def test_large_websearch_result
        # Create a large result similar to actual WebSearch output
        links = (1..20).map { |i| %({"title":"Result #{i}","url":"https://example.com/#{i}"}) }
        content = <<~CONTENT
          Web search results for query: "test query"
          
          Found multiple results:
          
          Links: [#{links.join(',')}]
          
          Summary of results:
          #{(1..50).map { |i| "Line #{i}: Additional information about search result #{i}" }.join("\n")}
        CONTENT
        
        msg = create_tool_result(content)
        output = @formatter.format_message(msg)
        
        refute_nil output
        lines = output.split("\n")
        
        assert_match(/📋 Result: \[\d+ lines, \d+\.\dKB\]/, lines[0])
        assert_equal "  Web search results for query: \"test query\"", lines[1]
        assert_equal "  ...", lines[6] # Should have ellipsis after 5 preview lines
      end
      
      private
      
      def create_tool_result(content)
        json = {
          "type" => "user",
          "message" => {
            "content" => [
              {
                "type" => "tool_result",
                "content" => content,
                "is_error" => false
              }
            ]
          }
        }
        Messages::Base.from_json(json)
      end
    end
  end
end