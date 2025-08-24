# frozen_string_literal: true

require_relative "integration_helper"

module AutoClaude
  module IntegrationTest
    class BasicClaudeTest < Base
      def test_todays_date_via_cli
        result = run_auto_claude_cli("What is today's date? Answer in YYYY-MM-DD format.")

        assert result[:success], "Command should succeed. stderr: #{result[:stderr]}"

        # Claude's response should contain today's date
        assert_date_response(result[:stdout])

        # Log output for debugging
        skip unless ENV["DEBUG"]

        puts "\n=== CLI Output ==="
        puts result[:stdout]
        puts "=================="
      end

      def test_todays_date_via_api
        result = run_auto_claude_api("What is today's date? Answer in YYYY-MM-DD format.")

        assert result[:success], "API call should succeed. Error: #{result[:error]&.message}"

        # Check the result contains today's date
        refute_nil result[:result], "Should have a result"
        assert_date_response(result[:result])

        # Verify we got messages
        refute_empty result[:messages] if result[:messages]

        # Log output for debugging
        skip unless ENV["DEBUG"]

        puts "\n=== API Result ==="
        puts result[:result]
        puts "=================="
      end

      def test_simple_math_via_cli
        result = run_auto_claude_cli("What is 42 + 17? Answer with just the number.")

        assert result[:success], "Command should succeed"

        # Should contain 59 somewhere in the response
        assert_match(/\b59\b/, result[:stdout], "Response should contain the answer 59")
      end

      def test_with_model_option
        # Test passing Claude options
        result = run_auto_claude_cli(
          "Say 'Hello from Claude' exactly",
          claude_options: ["--max-tokens", "50"]
        )

        assert result[:success], "Command should succeed with options"
        assert_match(/Hello from Claude/i, result[:stdout],
                     "Response should contain the requested phrase")
      end

      def test_error_handling
        # Test with an option that might cause an error
        # Using an invalid model to trigger an error
        result = run_auto_claude_cli(
          "Test prompt",
          claude_options: ["--model", "invalid-model-xyz"]
        )

        # This should fail
        refute result[:success], "Command should fail with invalid model"
      end
    end
  end
end
