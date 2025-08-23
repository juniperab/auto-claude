require 'test_helper'
require 'auto_claude/output/helpers/result_formatter'
require 'auto_claude/output/formatter_config'

module AutoClaude
  module Output
    module Helpers
      class ResultFormatterTest < Minitest::Test
        def setup
          @config = FormatterConfig.new
          @formatter = ResultFormatter.new(@config)
        end
        
        def test_smart_indent_no_existing_indent
          # Lines with no indentation should get 8 spaces
          output = "Line 1\nLine 2\nLine 3"
          result = @formatter.format(output)
          
          assert_match(/^   Result:/, result)
          assert_match(/^        Line 1$/, result)
          assert_match(/^        Line 2$/, result)
          assert_match(/^        Line 3$/, result)
        end
        
        def test_smart_indent_with_existing_indent
          # Lines already indented 4 spaces should get 4 more to reach 8
          output = "    Line 1\n    Line 2\n    Line 3"
          result = @formatter.format(output)
          
          assert_match(/^        Line 1$/, result)
          assert_match(/^        Line 2$/, result)
          assert_match(/^        Line 3$/, result)
        end
        
        def test_smart_indent_preserves_relative_indents
          # Should preserve relative indentation
          output = "Line 1\n  Sub item\n    Nested item\nLine 2"
          result = @formatter.format(output)
          
          assert_match(/^        Line 1$/, result)
          assert_match(/^          Sub item$/, result)  # 8 + 2 = 10 spaces
          assert_match(/^            Nested item$/, result)  # 8 + 4 = 12 spaces
          assert_match(/^        Line 2$/, result)
        end
        
        def test_smart_indent_with_mixed_indentation
          # Minimum indent is 2, so add 6 to reach 8
          output = "  Line 1\n    Line 2\n      Line 3\n  Line 4"
          result = @formatter.format(output)
          
          assert_match(/^        Line 1$/, result)  # 6 + 2 = 8
          assert_match(/^          Line 2$/, result)  # 6 + 4 = 10
          assert_match(/^            Line 3$/, result)  # 6 + 6 = 12
          assert_match(/^        Line 4$/, result)  # 6 + 2 = 8
        end
        
        def test_smart_indent_already_indented_enough
          # Lines already at 8+ spaces should not be further indented
          output = "        Line 1\n          Line 2\n        Line 3"
          result = @formatter.format(output)
          
          assert_match(/^        Line 1$/, result)
          assert_match(/^          Line 2$/, result)
          assert_match(/^        Line 3$/, result)
        end
        
        def test_smart_indent_with_tabs
          # Tabs should be converted to 4 spaces
          output = "\tLine 1\n\t\tLine 2\n\tLine 3"
          result = @formatter.format(output)
          
          # Tab = 4 spaces, so add 4 more to reach 8
          assert_match(/^        Line 1$/, result)  # 4 + 4 = 8
          assert_match(/^            Line 2$/, result)  # 4 + 8 = 12
          assert_match(/^        Line 3$/, result)  # 4 + 4 = 8
        end
        
        def test_smart_indent_mixed_tabs_and_spaces
          # Mixed tabs and spaces
          output = "\tLine 1\n  \tLine 2\n    Line 3"
          result = @formatter.format(output)
          
          # Minimum is 4 spaces (tab), so add 4 to reach 8
          assert_match(/^        Line 1$/, result)  # 4 + 4 = 8
          assert_match(/^          Line 2$/, result)  # 4 + 2 + 4 = 10
          assert_match(/^        Line 3$/, result)  # 4 + 4 = 8
        end
        
        def test_smart_indent_ignores_empty_lines
          # Empty lines shouldn't affect minimum indent calculation
          output = "  Line 1\n\n    Line 2\n  \n  Line 3"
          result = @formatter.format(output)
          
          lines = result.split("\n")
          # Should have header + 5 lines
          assert_equal 6, lines.length
          
          # All non-empty lines should be indented to at least 8 spaces
          assert_match(/^        Line 1$/, result)
          assert_match(/^          Line 2$/, result)
          assert_match(/^        Line 3$/, result)
        end
        
        def test_ellipsis_matches_indent
          # Ellipsis should match the indentation of content
          long_output = (1..10).map { |i| "  Line #{i}" }.join("\n")
          result = @formatter.format(long_output)
          
          # Should show 5 lines plus ellipsis
          lines = result.split("\n")
          assert_equal 7, lines.length  # Header + 5 lines + ellipsis
          
          # Ellipsis should have same indent as lines (8 spaces)
          assert_match(/^        \.\.\.$/, lines.last)
        end
        
        def test_single_line_result_not_indented
          # Single short lines should not be indented
          output = "Success!"
          result = @formatter.format(output)
          
          assert_equal "   Result: Success!", result
        end
        
        def test_empty_result
          output = ""
          result = @formatter.format(output)
          
          assert_equal "   Result: (empty)", result
        end
      end
    end
  end
end