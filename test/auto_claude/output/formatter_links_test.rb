require 'test_helper'
require 'auto_claude/output/formatter'
require 'auto_claude/messages/base'

module AutoClaude
  module Output
    class FormatterLinksTest < Minitest::Test
      def setup
        @formatter = Formatter.new(color: false, truncate: false)
      end
      
      def test_format_links_single_link
        content = 'Links: [{"title":"Ruby Documentation","url":"https://www.ruby-lang.org/en/documentation/"}]'
        
        msg = create_tool_result(content)
        output = @formatter.format_message(msg)
        
        lines = output.split("\n")
        assert_match(/   Result: \[1 lines, 0\.\dKB\]/, lines[0])
        assert_equal "  Links:", lines[1]
        assert_equal "    • Ruby Documentation (ruby-lang.org)", lines[2]
      end
      
      def test_format_links_multiple_links
        links = [
          '{"title":"First Result","url":"https://example.com/page1"}',
          '{"title":"Second Result","url":"https://test.org/page2"}',
          '{"title":"Third Result","url":"https://www.demo.net/page3"}'
        ]
        content = "Links: [#{links.join(',')}]"
        
        msg = create_tool_result(content)
        output = @formatter.format_message(msg)
        
        lines = output.split("\n")
        assert_match(/   Result: \[1 lines, 0\.\dKB\]/, lines[0])
        assert_equal "  Links:", lines[1]
        assert_equal "    • First Result (example.com)", lines[2]
        assert_equal "    • Second Result (test.org)", lines[3]
        assert_equal "    • Third Result (demo.net)", lines[4]
      end
      
      def test_format_links_more_than_five
        links = (1..8).map { |i| %{{"title":"Result #{i}","url":"https://site#{i}.com/page"}} }
        content = "Links: [#{links.join(',')}]"
        
        msg = create_tool_result(content)
        output = @formatter.format_message(msg)
        
        lines = output.split("\n")
        assert_match(/   Result: \[1 lines, 0\.\dKB\]/, lines[0])
        assert_equal "  Links:", lines[1]
        assert_equal "    • Result 1 (site1.com)", lines[2]
        assert_equal "    • Result 2 (site2.com)", lines[3]
        assert_equal "    • Result 3 (site3.com)", lines[4]
        assert_equal "    • Result 4 (site4.com)", lines[5]
        assert_equal "    • Result 5 (site5.com)", lines[6]
        assert_equal "  ...", lines[7]
      end
      
      def test_format_links_long_title_truncated
        long_title = "This is a very long title that should be truncated at fifty characters total"
        content = %{Links: [{"title":"#{long_title}","url":"https://example.com/"}]}
        
        msg = create_tool_result(content)
        output = @formatter.format_message(msg)
        
        lines = output.split("\n")
        assert_equal "  Links:", lines[1]
        # Title should be truncated to 50 chars (47 + "...")
        assert_equal "    • This is a very long title that should be trunca... (example.com)", lines[2]
      end
      
      def test_format_links_with_surrounding_content
        content = <<~CONTENT
          Web search results for query: "test"
          
          Links: [{"title":"Test Result","url":"https://test.com/"}]
          
          Summary: Found 1 result
        CONTENT
        
        msg = create_tool_result(content)
        output = @formatter.format_message(msg)
        
        lines = output.split("\n")
        assert_match(/   Result: \[5 lines, 0\.\dKB\]/, lines[0])
        # When Links are present, they're shown instead of the full content
        assert_equal "  Links:", lines[1]
        assert_equal "    • Test Result (test.com)", lines[2]
        assert_equal 4, lines.length # Header + Links header + 1 link + ellipsis (more content after Links)
      end
      
      def test_format_links_missing_fields
        # Test with missing title
        content1 = 'Links: [{"url":"https://example.com/"}]'
        msg1 = create_tool_result(content1)
        output1 = @formatter.format_message(msg1)
        assert_match(/• Untitled \(example\.com\)/, output1)
        
        # Test with missing url
        content2 = 'Links: [{"title":"Some Title"}]'
        msg2 = create_tool_result(content2)
        output2 = @formatter.format_message(msg2)
        assert_match(/• Some Title \(unknown\)/, output2)
        
        # Test with both missing
        content3 = 'Links: [{}]'
        msg3 = create_tool_result(content3)
        output3 = @formatter.format_message(msg3)
        assert_match(/• Untitled \(unknown\)/, output3)
      end
      
      def test_extract_domain_various_urls
        link_parser = Helpers::LinkParser.new
        
        # Test standard URLs
        assert_equal "example.com", link_parser.send(:extract_domain, "https://example.com/page")
        assert_equal "example.com", link_parser.send(:extract_domain, "http://example.com/page")
        assert_equal "example.com", link_parser.send(:extract_domain, "https://www.example.com/page")
        
        # Test subdomains
        assert_equal "api.example.com", link_parser.send(:extract_domain, "https://api.example.com/v1")
        
        # Test with ports
        assert_equal "localhost:3000", link_parser.send(:extract_domain, "http://localhost:3000/test")
        
        # Test edge cases
        assert_equal "unknown", link_parser.send(:extract_domain, nil)
        assert_equal "unknown", link_parser.send(:extract_domain, "")
        assert_equal "unknown", link_parser.send(:extract_domain, "not-a-url")
      end
      
      def test_format_links_invalid_json
        # Test malformed JSON
        content = 'Links: [this is not json]'
        msg = create_tool_result(content)
        output = @formatter.format_message(msg)
        
        # Should fall back to displaying the line as-is
        lines = output.split("\n")
        assert_equal "  Links: [this is not json]", lines[1]
      end
      
      def test_format_links_empty_array
        content = 'Links: []'
        msg = create_tool_result(content)
        output = @formatter.format_message(msg)
        
        lines = output.split("\n")
        assert_equal "  Links:", lines[1]
        # No link items should be present
        refute_match(/•/, output)
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