# frozen_string_literal: true

require "test_helper"
require "auto_claude/output/formatters/bash"
require "auto_claude/output/formatter_config"

module AutoClaude
  module Output
    module Formatters
      class BashTest < Minitest::Test
        def setup
          @config = FormatterConfig.new
          @formatter = Bash.new(@config)
        end

        def test_format_short_command
          input = { "command" => "ls -la" }
          result = @formatter.format(input)

          assert_equal "🖥️ Running: ls -la", result
        end

        def test_format_long_command_with_description
          long_command = "very long command " * 10
          input = {
            "command" => long_command,
            "description" => "List files"
          }
          result = @formatter.format(input)

          assert_equal "🖥️ Executing: List files", result
        end

        def test_format_long_command_without_description
          long_command = "very long command " * 10
          input = { "command" => long_command }
          result = @formatter.format(input)

          assert_equal "🖥️ Running: #{long_command}", result
        end

        def test_format_with_symbol_keys
          input = { command: "pwd" }
          result = @formatter.format(input)

          assert_equal "🖥️ Running: pwd", result
        end

        def test_format_with_nil_command
          input = { "description" => "Something" }
          result = @formatter.format(input)

          assert_equal "🖥️ Running: unknown", result
        end

        def test_format_with_empty_input
          input = {}
          result = @formatter.format(input)

          assert_equal "🖥️ Running: unknown", result
        end

        def test_format_with_nil_input
          result = @formatter.format(nil)

          assert_equal "🖥️ Running: unknown", result
        end

        def test_command_length_threshold
          # Test exactly at threshold (50 chars)
          command_fifty = "a" * 50
          input = {
            "command" => command_fifty,
            "description" => "Test"
          }
          result = @formatter.format(input)

          assert_equal "🖥️ Running: #{command_fifty}", result

          # Test just over threshold (51 chars)
          command_fifty_one = "a" * 51
          input = {
            "command" => command_fifty_one,
            "description" => "Test"
          }
          result = @formatter.format(input)

          assert_equal "🖥️ Executing: Test", result
        end
      end
    end
  end
end
