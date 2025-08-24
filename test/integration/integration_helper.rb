# frozen_string_literal: true

require "test_helper"
require "auto_claude"
require "date"
require "open3"

module AutoClaude
  module IntegrationTest
    # Base class for integration tests that use real Claude CLI
    class Base < Minitest::Test
      def self.integration_enabled?
        ENV["INTEGRATION"] == "true" || ENV["RUN_INTEGRATION_TESTS"] == "true"
      end

      def setup
        skip_unless_integration
        check_claude_cli_available!
      end

      def skip_unless_integration
        skip "Integration tests only run with INTEGRATION=true" unless self.class.integration_enabled?
      end

      private

      def check_claude_cli_available!
        stdout, _stderr, status = Open3.capture3("which", "claude")
        skip "Claude CLI not found in PATH" unless status.success? && !stdout.strip.empty?
      rescue StandardError => e
        skip "Cannot check for Claude CLI: #{e.message}"
      end

      # Run auto-claude with real Claude CLI and capture output
      def run_auto_claude_cli(prompt, options = {})
        # ALWAYS run in a temp directory to isolate from project
        Dir.mktmpdir("auto_claude_test") do |tmpdir|
          # Use provided directory or the temp directory
          working_dir = options[:working_directory] || tmpdir

          # Build command
          cmd = ["bundle", "exec", "ruby", "-Ilib", "bin/auto-claude"]

          # Always specify working directory
          cmd << "-d"
          cmd << working_dir

          cmd << prompt

          # Add any additional Claude options
          if options[:claude_options]
            cmd << "--"
            cmd.concat(options[:claude_options])
          end

          # Run the command
          stdout, stderr, status = Open3.capture3(*cmd)

          {
            stdout: stdout,
            stderr: stderr,
            status: status,
            success: status.success?,
            working_directory: working_dir
          }
        end
      end

      # Alternative: run using the Ruby API directly
      def run_auto_claude_api(prompt, options = {})
        # ALWAYS run in a temp directory to isolate from project
        Dir.mktmpdir("auto_claude_test") do |tmpdir|
          # Use provided directory or the temp directory
          working_dir = options[:directory] || tmpdir

          output = AutoClaude::Output::Memory.new
          client_options = {
            output: output,
            claude_options: options[:claude_options] || [],
            directory: working_dir
          }

          client = AutoClaude::Client.new(**client_options)

          session = client.run(prompt)

          {
            result: session.result&.content,
            session: session,
            output: output,
            messages: output.messages,
            success: session.success?,
            working_directory: working_dir
          }
        end
      rescue StandardError => e
        {
          error: e,
          success: false
        }
      end

      # Extract date from text that may contain extra words
      def extract_date(text)
        # Match various date formats
        patterns = [
          /\b(\d{4}-\d{2}-\d{2})\b/,           # 2024-01-15
          %r{\b(\d{4}/\d{2}/\d{2})\b},         # 2024/01/15
          %r{\b(\d{1,2}[-/]\d{1,2}[-/]\d{4})\b} # 1/15/2024 or 01-15-2024
        ]

        patterns.each do |pattern|
          match = text.match(pattern)
          return normalize_date(match[1]) if match
        end

        nil
      end

      # Normalize different date formats to yyyy-mm-dd
      def normalize_date(date_str)
        # Already in correct format
        return date_str if date_str.match?(/^\d{4}-\d{2}-\d{2}$/)

        # Try parsing with Date
        begin
          parsed = Date.parse(date_str)
          parsed.strftime("%Y-%m-%d")
        rescue StandardError
          date_str
        end
      end

      # Check if response contains today's date (with fuzzy matching)
      def assert_contains_todays_date(text, message = nil)
        today = Date.today.strftime("%Y-%m-%d")
        extracted_date = extract_date(text)

        refute_nil extracted_date,
                   "#{message || "Response"} should contain a date. Got: #{text.inspect}"

        assert_equal today, extracted_date,
                     "#{message || "Response"} should contain today's date (#{today}). Found: #{extracted_date}"
      end

      # Check if response contains a reasonable response about a date
      def assert_date_response(text)
        # Should mention date-related words
        date_indicators = ["date", "today", Date.today.strftime("%B"), "2024", "2025"]

        found_indicator = date_indicators.any? { |word| text.downcase.include?(word.downcase) }

        assert found_indicator,
               "Response should mention date-related terms. Got: #{text.inspect}"

        # Should contain an actual date
        assert_contains_todays_date(text)
      end
    end
  end
end
