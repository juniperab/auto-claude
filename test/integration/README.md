# Integration Tests

These tests exercise auto-claude with the real Claude CLI. They are not run by default.

## Prerequisites

1. Claude CLI must be installed and available in PATH
2. Valid Claude API credentials configured

## Running Integration Tests

```bash
# Run integration tests only (automatically sets INTEGRATION=true)
rake test:integration

# Run with debug output
DEBUG=true rake test:integration

# Run all tests including integration
rake test:all

# Run a specific integration test file
INTEGRATION=true ruby -Itest:lib test/integration/basic_claude_test.rb
```

## What These Tests Do

- **test_todays_date_via_cli**: Runs auto-claude via command line, asks for today's date
- **test_todays_date_via_api**: Uses Ruby API directly, asks for today's date  
- **test_simple_math_via_cli**: Tests basic math question
- **test_model_selection**: Tests different Claude models (Sonnet vs Haiku) and verifies they identify themselves correctly
- **test_error_handling**: Tests error conditions with invalid model names

## Important Notes

1. These tests make real API calls to Claude and will consume API credits
2. Responses are non-deterministic - tests use fuzzy matching
3. Tests may fail due to network issues or API rate limits
4. Integration tests are excluded from the default test suite

## Adding New Integration Tests

Create new test files in `test/integration/` that inherit from `AutoClaude::IntegrationTest::Base`:

```ruby
require_relative "integration_helper"

module AutoClaude
  module IntegrationTest
    class MyTest < Base
      def test_something
        result = run_auto_claude_cli("prompt")
        assert result[:success]
      end
    end
  end
end
```