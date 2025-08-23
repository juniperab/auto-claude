# frozen_string_literal: true

require "test_helper"
require "auto_claude/output/formatters/search"
require "auto_claude/output/formatter_config"

module AutoClaude
  module Output
    module Formatters
      class SearchTest < Minitest::Test
        def setup
          @config = FormatterConfig.new
          @formatter = Search.new(@config)
        end

        # LS operation tests
        def test_format_ls_basic
          input = { "path" => "/home/user" }
          result = @formatter.format("ls", input)

          assert_equal "📂 Listing /home/user/", result
        end

        def test_format_ls_with_ignore
          input = {
            "path" => "/home/user",
            "ignore" => "*.log"
          }
          result = @formatter.format("ls", input)

          assert_equal "📂 Listing /home/user/\n        filter: excluding *.log", result
        end

        def test_format_ls_default_path
          input = {}
          result = @formatter.format("ls", input)

          assert_equal "📂 Listing ./", result
        end

        # Glob operation tests
        def test_format_glob_basic
          input = { "pattern" => "**/*.rb" }
          result = @formatter.format("glob", input)

          assert_equal "🎯 Searching for **/*.rb", result
        end

        def test_format_glob_default_pattern
          input = {}
          result = @formatter.format("glob", input)

          assert_equal "🎯 Searching for *", result
        end

        # Grep operation tests
        def test_format_grep_basic
          input = { "pattern" => "TODO" }
          result = @formatter.format("grep", input)

          assert_equal "🔍 Searching for 'TODO'", result
        end

        def test_format_grep_with_path
          input = {
            "pattern" => "TODO",
            "path" => "/src"
          }
          result = @formatter.format("grep", input)

          assert_equal "🔍 Searching for 'TODO'\n        in: /src", result
        end

        def test_format_grep_with_context_c
          input = {
            "pattern" => "TODO",
            "-C" => 3
          }
          result = @formatter.format("grep", input)

          assert_equal "🔍 Searching for 'TODO'\n        context: ±3 lines", result
        end

        def test_format_grep_with_context_a_and_b_equal
          input = {
            "pattern" => "TODO",
            "-A" => 2,
            "-B" => 2
          }
          result = @formatter.format("grep", input)

          assert_equal "🔍 Searching for 'TODO'\n        context: ±2 lines", result
        end

        def test_format_grep_with_context_a_and_b_different
          input = {
            "pattern" => "TODO",
            "-A" => 2,
            "-B" => 3
          }
          result = @formatter.format("grep", input)

          # Should not show context when A and B are different
          assert_equal "🔍 Searching for 'TODO'", result
        end

        def test_format_grep_with_all_options
          input = {
            "pattern" => "TODO",
            "path" => "/src",
            "-C" => 5
          }
          result = @formatter.format("grep", input)

          assert_equal "🔍 Searching for 'TODO'\n        in: /src\n        context: ±5 lines", result
        end

        # WebSearch operation tests
        def test_format_websearch_basic
          input = { "query" => "ruby programming" }
          result = @formatter.format("websearch", input)

          assert_equal "🔍 Web searching: 'ruby programming'", result
        end

        def test_format_websearch_empty_query
          input = {}
          result = @formatter.format("websearch", input)

          assert_equal "🔍 Web searching: ''", result
        end

        # Unknown operation test
        def test_format_unknown_operation
          input = { "pattern" => "test" }
          result = @formatter.format("unknown_search", input)

          assert_equal "🔍 Search: unknown_search", result
        end

        # Symbol key tests
        def test_format_with_symbol_keys
          input = { pattern: "TODO" }
          result = @formatter.format("grep", input)

          assert_equal "🔍 Searching for 'TODO'", result
        end

        # Nil input tests
        def test_format_with_nil_input
          result = @formatter.format("ls", nil)

          assert_equal "📂 Listing ./", result
        end

        # Extract grep context tests
        def test_extract_grep_context_with_c
          input = { "-C" => 3 }
          context = @formatter.send(:extract_grep_context, input)

          assert_equal 3, context
        end

        def test_extract_grep_context_with_matching_a_b
          input = { "-A" => 2, "-B" => 2 }
          context = @formatter.send(:extract_grep_context, input)

          assert_equal 2, context
        end

        def test_extract_grep_context_with_different_a_b
          input = { "-A" => 2, "-B" => 3 }
          context = @formatter.send(:extract_grep_context, input)

          assert_nil context
        end

        def test_extract_grep_context_with_nil
          context = @formatter.send(:extract_grep_context, nil)

          assert_nil context
        end
      end
    end
  end
end
