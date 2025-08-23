# frozen_string_literal: true

require "test_helper"
require "auto_claude/output/formatters/file"
require "auto_claude/output/formatter_config"

module AutoClaude
  module Output
    module Formatters
      class FileTest < Minitest::Test
        def setup
          @config = FormatterConfig.new
          @formatter = File.new(@config)
        end

        # Read operation tests
        def test_format_read_basic
          input = { "file_path" => "/path/to/file.rb" }
          result = @formatter.format("read", input)

          assert_equal "👀 Reading /path/to/file.rb", result
        end

        def test_format_read_with_lines
          input = {
            "file_path" => "/path/to/file.rb",
            "offset" => 10,
            "limit" => 20
          }
          result = @formatter.format("read", input)

          assert_equal "👀 Reading /path/to/file.rb (lines 10-20)", result
        end

        def test_format_read_nil_path
          input = {}
          result = @formatter.format("read", input)

          assert_equal "👀 Reading unknown", result
        end

        # Write operation tests
        def test_format_write_small_file
          input = {
            "file_path" => "/path/to/file.rb",
            "content" => "small content"
          }
          result = @formatter.format("write", input)

          assert_equal "✍️ Writing to /path/to/file.rb", result
        end

        def test_format_write_large_file
          large_content = "x" * 2048 # 2KB
          input = {
            "file_path" => "/path/to/file.rb",
            "content" => large_content
          }
          result = @formatter.format("write", input)

          assert_equal "✍️ Writing to /path/to/file.rb\n        size: 2.0KB", result
        end

        def test_format_write_nil_content
          input = { "file_path" => "/path/to/file.rb" }
          result = @formatter.format("write", input)

          assert_equal "✍️ Writing to /path/to/file.rb", result
        end

        # Edit operation tests
        def test_format_edit
          input = { "file_path" => "/path/to/file.rb" }
          result = @formatter.format("edit", input)

          assert_equal "✏️ Editing /path/to/file.rb", result
        end

        def test_format_edit_nil_path
          input = {}
          result = @formatter.format("edit", input)

          assert_equal "✏️ Editing unknown", result
        end

        # MultiEdit operation tests
        def test_format_multiedit_multiple_edits
          input = {
            "file_path" => "/path/to/file.rb",
            "edits" => [
              { "old" => "foo", "new" => "bar" },
              { "old" => "baz", "new" => "qux" },
              { "old" => "hello", "new" => "world" }
            ]
          }
          result = @formatter.format("multiedit", input)

          assert_equal "✂️ Bulk editing /path/to/file.rb\n        changes: 3 edits", result
        end

        def test_format_multiedit_empty_edits
          input = {
            "file_path" => "/path/to/file.rb",
            "edits" => []
          }
          result = @formatter.format("multiedit", input)

          assert_equal "✂️ Bulk editing /path/to/file.rb\n        changes: 0 edits", result
        end

        def test_format_multiedit_nil_edits
          input = { "file_path" => "/path/to/file.rb" }
          result = @formatter.format("multiedit", input)

          assert_equal "✂️ Bulk editing /path/to/file.rb\n        changes: 0 edits", result
        end

        # Unknown operation test
        def test_format_unknown_operation
          input = { "file_path" => "/path/to/file.rb" }
          result = @formatter.format("unknown_op", input)

          assert_equal "📄 File operation: unknown_op", result
        end

        # Symbol key tests
        def test_format_with_symbol_keys
          input = { file_path: "/path/to/file.rb" }
          result = @formatter.format("read", input)

          assert_equal "👀 Reading /path/to/file.rb", result
        end

        # Edge cases
        def test_format_with_nil_input
          result = @formatter.format("read", nil)

          assert_equal "👀 Reading unknown", result
        end

        def test_write_size_calculation_edge_cases
          # Exactly 1KB
          input = {
            "file_path" => "/file.rb",
            "content" => "x" * 1024
          }
          result = @formatter.format("write", input)

          assert_equal "✍️ Writing to /file.rb", result

          # Just over 1KB
          input = {
            "file_path" => "/file.rb",
            "content" => "x" * 1025
          }
          result = @formatter.format("write", input)

          assert_equal "✍️ Writing to /file.rb\n        size: 1.0KB", result
        end
      end
    end
  end
end
