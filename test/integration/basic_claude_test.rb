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

      def test_model_selection
        # Test that different models can be selected and they correctly identify themselves
        prompt = "What model are you? Just say the model name (Sonnet, Opus, or Haiku)"

        # Test with Sonnet model
        result_sonnet = run_auto_claude_cli(
          prompt,
          claude_options: ["--model", "sonnet"]
        )

        skip "Sonnet model not available: #{result_sonnet[:stderr]}" unless result_sonnet[:success]

        assert_match(/Sonnet/i, result_sonnet[:stdout],
                     "Sonnet model should identify itself as Sonnet")

        # Test with Haiku model
        result_haiku = run_auto_claude_cli(
          prompt,
          claude_options: ["--model", "haiku"]
        )

        skip "Haiku model not available: #{result_haiku[:stderr]}" unless result_haiku[:success]

        assert_match(/Haiku/i, result_haiku[:stdout],
                     "Haiku model should identify itself as Haiku")

        # Verify the outputs are different (different models gave different responses)
        refute_equal result_sonnet[:stdout], result_haiku[:stdout],
                     "Different models should produce different outputs"

        # Debug output if requested
        skip unless ENV["DEBUG"]

        puts "\n=== Sonnet Response ==="
        puts result_sonnet[:stdout]
        puts "\n=== Haiku Response ==="
        puts result_haiku[:stdout]
        puts "===================="
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
