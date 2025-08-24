# frozen_string_literal: true

require_relative "integration_helper"

module AutoClaude
  module IntegrationTest
    class IsolationTest < Base
      def test_claude_cannot_access_project_directory
        # Try to list files in the parent directories
        result = run_auto_claude_cli(
          "Run ls .. and pwd to show where I am"
        )

        skip "Claude CLI failed: #{result[:stderr]}" unless result[:success]

        # Claude should NOT see our project files
        refute_match(/Gemfile/, result[:stdout],
                     "Claude should NOT see Gemfile from project")
        refute_match(/Rakefile/, result[:stdout],
                     "Claude should NOT see Rakefile from project")
        refute_match(/auto_claude\.gemspec/, result[:stdout],
                     "Claude should NOT see gemspec from project")

        # Claude should be in a temp directory
        assert_match(%r{/tmp/|/var/folders/}, result[:stdout],
                     "Claude should be running in a temp directory")

        skip unless ENV["DEBUG"]

        puts "\n=== Isolation Test ==="
        puts "Working directory: #{result[:working_directory]}"
        puts "Claude output:"
        puts result[:stdout]
        puts "==================="
      end

      def test_temp_directory_is_empty_by_default
        result = run_auto_claude_cli("Run ls -la")

        skip "Claude CLI failed: #{result[:stderr]}" unless result[:success]

        # Directory should be mostly empty (just . and ..)
        lines = result[:stdout].split("\n")
        file_count = lines.select { |l| l.match(/^[d-]/) }.count

        assert_operator file_count, :<=, 3, "Temp directory should be empty. Found #{file_count} entries"
      end
    end
  end
end
