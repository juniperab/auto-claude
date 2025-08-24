# frozen_string_literal: true

require_relative "integration_helper"
require "tmpdir"

module AutoClaude
  module IntegrationTest
    class DirectoryVerificationTest < Base
      def test_specified_directory_overrides_default
        # Create a specific directory with a marker file
        Dir.mktmpdir("specific_dir") do |specific_dir|
          marker_file = File.join(specific_dir, "MARKER_FILE.txt")
          File.write(marker_file, "This is the specific directory")

          # Run Claude with the specific directory
          result = run_auto_claude_cli(
            "Run ls and pwd",
            working_directory: specific_dir
          )

          skip "Claude CLI failed: #{result[:stderr]}" unless result[:success]

          # Verify Claude is in the specific directory we provided
          assert_match(/MARKER_FILE\.txt/, result[:stdout],
                       "Claude should see MARKER_FILE.txt in the specified directory")

          # Verify the working directory is the one we specified
          assert_equal specific_dir, result[:working_directory],
                       "Result should report the specified working directory"

          # The pwd output should show our specific directory
          assert(result[:stdout].include?(specific_dir) ||
                 result[:stdout].include?("/private#{specific_dir}"),
                 "PWD should show our specific directory: #{specific_dir}")
        end
      end

      def test_default_directory_is_empty
        # Run without specifying a directory
        result = run_auto_claude_cli("Run ls -la")

        skip "Claude CLI failed: #{result[:stderr]}" unless result[:success]

        # The default temp directory should be empty
        refute_match(/MARKER_FILE/, result[:stdout],
                     "Default directory should not have any marker files")

        # Verify we got a temp directory path back
        assert_match(%r{/tmp/|/var/folders/}, result[:working_directory],
                     "Should be using a temp directory by default")
      end

      def test_api_mode_respects_specified_directory
        Dir.mktmpdir("api_specific") do |specific_dir|
          File.write(File.join(specific_dir, "API_MARKER.txt"), "API directory")

          result = run_auto_claude_api(
            "List files with ls",
            directory: specific_dir
          )

          skip "API call failed" unless result[:success]

          assert_match(/API_MARKER\.txt/, result[:result],
                       "API mode should see marker file in specified directory")

          assert_equal specific_dir, result[:working_directory],
                       "API should report the specified directory"
        end
      end

      def test_different_calls_use_different_temp_dirs_by_default
        # Run twice without specifying directories
        result1 = run_auto_claude_cli("Run pwd")
        result2 = run_auto_claude_cli("Run pwd")

        skip "Claude CLI failed" unless result1[:success] && result2[:success]

        # Each call should get a different temp directory
        refute_equal result1[:working_directory], result2[:working_directory],
                     "Each call should use a different temp directory"

        skip unless ENV["DEBUG"]

        puts "\n=== Directory Isolation ==="
        puts "First call directory: #{result1[:working_directory]}"
        puts "Second call directory: #{result2[:working_directory]}"
        puts "========================="
      end
    end
  end
end
