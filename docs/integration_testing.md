# Integration Testing Guide

## Overview

The auto-claude integration test framework enables testing with the real Claude CLI, making actual API calls to verify end-to-end functionality. These tests are kept separate from unit tests due to their unique requirements and characteristics.

### Key Characteristics

- **Real API Calls**: Tests make actual requests to Claude's API
- **Non-deterministic Output**: Same prompts may produce different responses
- **Cost Consideration**: Each test consumes API credits
- **Execution Time**: Slower than unit tests due to network and processing latency
- **Optional Execution**: Must be explicitly enabled to run

## Directory Structure

```
test/
├── integration/
│   ├── README.md                 # Quick reference
│   ├── integration_helper.rb     # Base class and utilities
│   └── basic_claude_test.rb      # Example tests
└── auto_claude/                  # Unit tests (use mocks)
```

## Running Integration Tests

### Running Tests

```bash
# Run integration tests (automatically sets INTEGRATION=true)
rake test:integration

# With debug output to see Claude's responses
DEBUG=true rake test:integration

# Run ALL tests including integration
rake test:all

# Run specific test file (requires manual flag)
INTEGRATION=true ruby -Itest:lib test/integration/basic_claude_test.rb

# Alternative: Set environment variable for session
export INTEGRATION=true
ruby -Itest:lib test/integration/basic_claude_test.rb
```

### Alternative Environment Variables

The integration tests check for either of these flags:
- `INTEGRATION=true`
- `RUN_INTEGRATION_TESTS=true`

This is mainly useful when running individual test files directly without rake.

## Test Execution Modes: CLI vs API

The framework provides two fundamentally different ways to test auto-claude, each simulating different real-world usage scenarios:

### Understanding the Difference

**`run_auto_claude_cli` (CLI Mode)**: Simulates a user typing `auto-claude "prompt"` in their terminal. This spawns a new Ruby process that loads the entire application from scratch, exactly as it would happen in real usage.

**`run_auto_claude_api` (API Mode)**: Simulates a Ruby developer using auto-claude as a library in their code via `require 'auto_claude'`. This runs within the same process as your tests.

Think of it this way:
- CLI mode tests: "Does the command-line tool work correctly for end users?"
- API mode tests: "Does the Ruby library work correctly for developers?"

### 1. CLI Execution Mode (`run_auto_claude_cli`)

This mode spawns a completely separate OS process, just like when a user runs the command in their terminal:

```ruby
def test_via_cli
  # What actually happens:
  # 1. Spawns: bundle exec ruby -Ilib bin/auto-claude "What is 2+2?"
  # 2. New Ruby interpreter starts
  # 3. Loads all gems and code fresh
  # 4. Runs through CLI argument parsing
  # 5. Executes Claude and formats output
  # 6. Returns text output as if from terminal
  
  result = run_auto_claude_cli("What is 2+2?")
  
  # You get back exactly what a terminal user would see
  assert result[:success]
  assert_match(/4/, result[:stdout])  # Formatted, colored output
  
  # Example stdout (what user sees in terminal):
  # 🤖 Assistant: The answer is 4.
  #
  # ✅ Result: 4
end
```

**Key Characteristics:**
- **Process isolation**: Each test runs in a fresh process with no shared state
- **Terminal output**: Returns formatted, colored text with emojis
- **Argument parsing**: Tests the full CLI argument handling
- **Real command**: Tests the actual `auto-claude` command users run

**When to use CLI mode:**
```ruby
# Testing command-line arguments and options
def test_cli_arguments
  result = run_auto_claude_cli("Hello", 
    claude_options: ["--model", "claude-3-haiku-20240307", "--no-cache"])
  assert result[:success]
end

# Testing output formatting for terminal users
def test_terminal_formatting
  result = run_auto_claude_cli("Write code")
  assert_match(/```ruby/, result[:stdout])  # Code blocks formatted
  assert_match(/🤖/, result[:stdout])       # Emojis present
end

# Testing error messages users would see
def test_user_facing_errors
  result = run_auto_claude_cli("Test", claude_options: ["--invalid-flag"])
  assert_match(/Error/, result[:stderr])
  refute result[:success]
end
```

**What you get back:**
```ruby
{
  stdout: "🤖 Assistant: The answer is 4.\n\n✅ Result: 4",  # Formatted terminal output
  stderr: "",                                                # Any error output
  status: #<Process::Status: pid 12345 exit 0>,             # OS process status
  success: true                                              # Convenience boolean
}
```

### 2. Ruby API Mode (`run_auto_claude_api`)

This mode uses auto-claude as a library within your test process, like a Ruby developer would:

```ruby
def test_via_api
  # What actually happens:
  # 1. Creates AutoClaude::Client instance in current process
  # 2. Runs Claude through the Ruby API
  # 3. Captures structured data and objects
  # 4. Returns Ruby objects, not text
  
  result = run_auto_claude_api("What is 2+2?")
  
  # You get back Ruby objects and data
  assert result[:success]
  assert_equal "4", result[:result]  # Direct access to result string
  
  # Access rich session data
  session = result[:session]
  assert_equal 0.0001, session.cost
  assert_equal({input: 10, output: 5}, session.token_usage)
end
```

**Key Characteristics:**
- **In-process execution**: Runs in the same Ruby process as tests
- **Structured data**: Returns Ruby objects, not formatted text
- **Direct API access**: Tests the Client class directly
- **Memory output**: No terminal formatting, just raw data

**When to use API mode:**
```ruby
# Testing callbacks and streaming
def test_message_callbacks
  messages_received = []
  
  result = run_auto_claude_api("Count to 3") do |message|
    messages_received << {type: message.type, content: message.content}
  end
  
  # Can inspect each message as it arrived
  assert messages_received.any? { |m| m[:type] == :assistant }
  assert messages_received.any? { |m| m[:content].include?("1") }
end

# Testing session metadata and costs
def test_api_metadata
  result = run_auto_claude_api("Hello")
  
  session = result[:session]
  assert session.success?
  assert session.cost > 0
  assert session.duration_ms > 0
  assert_equal "test_session_id", session.session_id
end

# Testing error handling in Ruby code
def test_api_error_handling
  result = run_auto_claude_api("Cause an error somehow")
  
  if result[:error]
    assert_kind_of StandardError, result[:error]
    assert_match(/rate limit/, result[:error].message)
  end
end

# Testing memory output capture
def test_memory_output
  result = run_auto_claude_api("Say hello")
  
  # Access all messages that were output
  output = result[:output]
  messages = output.messages
  
  assert messages.first.is_a?(AutoClaude::Messages::TextMessage)
  assert_equal "Hello!", messages.first.content
end
```

**What you get back:**
```ruby
{
  result: "4",                           # Direct result string
  session: #<AutoClaude::Session:0x123>, # Full session object
  output: #<AutoClaude::Output::Memory>,  # Memory output buffer
  messages: [...],                        # Array of message objects
  success: true,                          # Boolean status
  error: nil                              # Exception if failed
}
```

### Practical Comparison

Here's the same test written both ways to show the difference:

```ruby
# CLI Mode - Testing what users see
def test_math_cli
  result = run_auto_claude_cli("What is 25 * 4?")
  
  # Test the formatted output users would see
  assert_match(/🤖 Assistant:/, result[:stdout])
  assert_match(/100/, result[:stdout])
  assert_match(/✅ Result:/, result[:stdout])
  
  # We can't access internal details like cost or tokens
  # We only see the final formatted text output
end

# API Mode - Testing what developers get
def test_math_api
  result = run_auto_claude_api("What is 25 * 4?")
  
  # Test the actual data and objects
  assert_equal "100", result[:result]
  assert result[:session].cost > 0
  assert result[:session].token_usage[:input] > 5
  
  # We can inspect every message that was processed
  assistant_messages = result[:messages].select { |m| m.type == :assistant }
  assert assistant_messages.any? { |m| m.content.include?("100") }
end
```

### When to Use Each Mode

**Use CLI mode (`run_auto_claude_cli`) when testing:**
- Command-line argument parsing
- Terminal output formatting (colors, emojis)
- Error messages shown to users
- The complete end-to-end CLI experience
- Process isolation is important

**Use API mode (`run_auto_claude_api`) when testing:**
- Ruby API functionality
- Callbacks and streaming behavior
- Session metadata (costs, tokens, timing)
- Programmatic error handling
- Internal message processing
- Memory output capture

### Performance Considerations

```ruby
# CLI mode is slower - new process each time
def test_many_cli_calls
  10.times do
    run_auto_claude_cli("test")  # ~2-3 seconds each (process spawn + Claude)
  end
end

# API mode is faster - reuses process
def test_many_api_calls
  10.times do
    run_auto_claude_api("test")  # ~1-2 seconds each (just Claude)
  end
end
```

### Quick Reference: CLI vs API Mode

| Aspect | `run_auto_claude_cli` (CLI) | `run_auto_claude_api` (API) |
|--------|-------------------------|------------------------------|
| **What it simulates** | User running `auto-claude` in terminal | Developer using Ruby library |
| **Process model** | New process each call | Same process as tests |
| **Output format** | Formatted text with colors/emojis | Ruby objects and data |
| **Speed** | Slower (process spawn overhead) | Faster (in-process) |
| **Test isolation** | Complete (new process) | Shared process state |
| **Access to internals** | No (only stdout/stderr) | Yes (session, costs, tokens) |
| **Callbacks** | Not supported | Fully supported |
| **Best for testing** | CLI arguments, formatting | API functionality, callbacks |
| **Real-world usage** | Terminal users | Ruby developers |
| **Example return** | `"🤖 Assistant: 4"` | `{result: "4", session: ...}` |

## How Integration Tests Work

### Test Lifecycle

1. **Setup Phase**
   ```ruby
   def setup
     skip_unless_integration      # Check INTEGRATION flag
     check_claude_cli_available!  # Verify Claude CLI installed
   end
   ```

2. **Execution Phase**
   - No mocking - real processes are spawned
   - Actual API calls are made to Claude
   - Output is captured and returned

3. **Assertion Phase**
   - Use fuzzy matching for non-deterministic output
   - Focus on presence of key information
   - Avoid exact string comparisons

### Base Test Class

All integration tests inherit from `AutoClaude::IntegrationTest::Base`:

```ruby
require_relative "integration_helper"

module AutoClaude
  module IntegrationTest
    class MyTest < Base
      def test_something
        result = run_auto_claude_cli("Your prompt")
        assert result[:success]
      end
    end
  end
end
```

## Fuzzy Matching Utilities

The framework provides intelligent matching helpers for AI-generated content:

### Date Extraction and Validation

```ruby
# Extract dates from various formats
def extract_date(text)
  # Handles: 2024-01-15, 2024/01/15, 1/15/2024, etc.
  # Returns normalized YYYY-MM-DD format
end

# Assert today's date appears in response
def assert_contains_todays_date(text)
  today = Date.today.strftime("%Y-%m-%d")
  extracted = extract_date(text)
  assert_equal today, extracted
end

# Assert response mentions date-related terms
def assert_date_response(text)
  # Checks for: "date", "today", month names, years
  indicators = ["date", "today", Date.today.strftime("%B")]
  assert indicators.any? { |word| text.downcase.include?(word.downcase) }
end
```

### Usage Example

```ruby
def test_current_date
  result = run_auto_claude_cli("What is today's date?")
  
  # Don't do this - too strict
  # assert_equal "Today's date is 2024-01-15.", result[:stdout]
  
  # Do this - flexible matching
  assert_date_response(result[:stdout])
  assert_contains_todays_date(result[:stdout])
end
```

## Writing Integration Tests

### Step 1: Create Test File

Create a new file in `test/integration/` directory:

```ruby
require_relative "integration_helper"

module AutoClaude
  module IntegrationTest
    class FeatureTest < Base
      def test_feature_behavior
        # Your test implementation
      end
    end
  end
end
```

### Step 2: Implement Test Cases

#### Testing Output Formatting

```ruby
def test_formatted_output
  result = run_auto_claude_cli("Write a haiku about Ruby")
  
  assert result[:success]
  assert_match(/Ruby/i, result[:stdout])
  assert result[:stdout].lines.count >= 3  # Haikus have 3 lines
end
```

#### Testing with Options

```ruby
def test_model_selection
  result = run_auto_claude_cli("Hi", 
    claude_options: ["--model", "claude-3-haiku-20240307"])
  
  assert result[:success]
  # Haiku model tends to be concise
  assert result[:stdout].length < 500
end
```

#### Testing Error Handling

```ruby
def test_handles_errors_gracefully
  # Test with invalid option
  result = run_auto_claude_cli("Test", 
    claude_options: ["--invalid-option"])
  
  refute result[:success]
  assert_match(/error|invalid/i, result[:stderr])
end
```

#### Testing Callbacks (API Mode)

```ruby
def test_streaming_callbacks
  messages_received = []
  
  result = run_auto_claude_api("List 3 colors") do |message|
    messages_received << message.type
  end
  
  assert result[:success]
  assert messages_received.include?(:assistant)
  assert messages_received.include?(:result)
end
```

### Step 3: Handle Non-Deterministic Output

```ruby
def test_math_calculation
  result = run_auto_claude_cli("What is 15 + 27?")
  
  # BAD - Too specific
  # assert_equal "The answer is 42.", result[:stdout]
  
  # GOOD - Flexible patterns
  assert_match(/42/, result[:stdout])
  assert_match(/fifteen.*twenty.*seven|15.*27/i, result[:stdout])
  assert_match(/sum|total|equals|answer/i, result[:stdout])
end
```

## Debug Output

Enable debug output to see Claude's actual responses:

```bash
DEBUG=true rake test:integration
```

This prints responses for failing tests:

```
=== CLI Output ===
Today's date is January 15, 2024, which in YYYY-MM-DD format is 2024-01-15.
==================

=== API Result ===
2024-01-15
==================
```

## Common Testing Patterns

### Pattern 1: Resource Creation and Cleanup

```ruby
def test_file_operations
  Dir.mktmpdir do |dir|
    File.write("#{dir}/input.txt", "Test content")
    
    result = run_auto_claude_cli("Summarize input.txt", 
      working_directory: dir)
    
    assert_match(/test content/i, result[:stdout])
  end  # Temp directory automatically cleaned up
end
```

### Pattern 2: Timeout Handling

```ruby
def test_with_timeout
  Timeout::timeout(30) do
    result = run_auto_claude_cli("Complex task...")
    assert result[:success]
  end
rescue Timeout::Error
  skip "Test timed out - API may be slow"
end
```

### Pattern 3: Conditional Testing

```ruby
def test_expensive_operation
  skip "Expensive test - set RUN_EXPENSIVE=true to run" unless ENV["RUN_EXPENSIVE"]
  
  result = run_auto_claude_cli("Generate 1000 words about Ruby")
  assert result[:stdout].split.count >= 900
end
```

### Pattern 4: Testing Multiple Prompts

```ruby
def test_conversation_context
  prompts = [
    "My name is Alice",
    "What is my name?"
  ]
  
  prompts.each do |prompt|
    result = run_auto_claude_cli(prompt)
    assert result[:success]
  end
  
  # Note: Each run_auto_claude is independent
  # Context is not maintained between calls
end
```

## Best Practices

### Do's

1. **Use Fuzzy Matching**: Accept variations in AI output
   ```ruby
   assert_match(/hello|hi|greetings/i, response)
   ```

2. **Test Key Information**: Focus on essential content
   ```ruby
   assert response.include?("important_keyword")
   ```

3. **Clean Up Resources**: Always clean up created files/directories
   ```ruby
   Dir.mktmpdir do |dir|
     # Test with temp directory
   end  # Automatically cleaned
   ```

4. **Document Intent**: Explain what you're testing
   ```ruby
   # Test that Claude can perform basic arithmetic
   def test_simple_math
   ```

5. **Handle Timeouts**: API calls may be slow
   ```ruby
   Timeout::timeout(30) { run_test }
   ```

### Don'ts

1. **Don't Expect Exact Output**: AI responses vary
   ```ruby
   # BAD
   assert_equal "The answer is 42.", result
   
   # GOOD
   assert_match(/42/, result)
   ```

2. **Don't Run by Default**: Integration tests should be opt-in
   ```ruby
   skip_unless_integration  # Always include this
   ```

3. **Don't Test Too Much**: Each test costs API credits
   ```ruby
   # Combine related assertions in one test
   ```

4. **Don't Ignore Errors**: Check both success and failure paths
   ```ruby
   assert result[:success], "Failed: #{result[:stderr]}"
   ```

## Limitations and Considerations

### Technical Limitations

- **API Rate Limits**: Too many rapid requests may be throttled
- **Network Dependency**: Tests fail without internet connection
- **Claude CLI Required**: Must be installed and configured
- **Non-Determinism**: Same input may produce different output

### Cost Considerations

- Each test makes real API calls consuming credits
- Consider using cheaper models for testing when possible
- Group related assertions to minimize API calls
- Use `skip` for expensive tests

### Performance Considerations

- Integration tests are 10-100x slower than unit tests
- Network latency adds 1-5 seconds per test
- Claude processing time varies by prompt complexity
- Run integration tests separately from unit tests

## Troubleshooting

### Common Issues

**"Claude CLI not found in PATH"**
- Install Claude CLI: `pip install claude-cli`
- Verify installation: `which claude`

**"Integration tests only run with INTEGRATION=true"**
- Set environment variable: `export INTEGRATION=true`
- Or use rake task: `rake test:integration_only`

**Tests timeout**
- Increase timeout in test
- Check network connection
- Verify API key is valid

**Non-deterministic failures**
- Use more flexible assertions
- Add retry logic for flaky tests
- Increase acceptable ranges

### Debugging Tips

1. Enable debug output: `DEBUG=true`
2. Run single test: `ruby -Itest:lib test/integration/specific_test.rb -n test_method_name`
3. Check Claude CLI directly: `claude "test prompt"`
4. Verify API key: `echo $ANTHROPIC_API_KEY`

## Example Test Suite

Here's a complete example test file showcasing various patterns:

```ruby
require_relative "integration_helper"

module AutoClaude
  module IntegrationTest
    class ComprehensiveTest < Base
      # Basic functionality test
      def test_simple_prompt
        result = run_auto_claude_cli("Say hello")
        
        assert result[:success]
        assert_match(/hello|hi|greetings/i, result[:stdout])
      end
      
      # Test with specific model
      def test_model_selection
        result = run_auto_claude_cli("Be concise: what is 2+2?",
          claude_options: ["--model", "claude-3-haiku-20240307"])
        
        assert result[:success]
        assert_match(/4/, result[:stdout])
        assert result[:stdout].length < 100  # Haiku is concise
      end
      
      # Test API mode with callbacks
      def test_api_with_callbacks
        message_types = []
        
        result = run_auto_claude_api("Count to 3") do |msg|
          message_types << msg.type
        end
        
        assert result[:success]
        assert message_types.include?(:assistant)
        assert_match(/1.*2.*3/m, result[:result])
      end
      
      # Test error handling
      def test_handles_invalid_options
        result = run_auto_claude_cli("Test",
          claude_options: ["--invalid-flag"])
        
        refute result[:success]
        assert result[:stderr].length > 0
      end
      
      # Test with file context
      def test_with_temp_file
        Dir.mktmpdir do |dir|
          file_path = "#{dir}/test.txt"
          File.write(file_path, "Ruby is awesome!")
          
          result = run_auto_claude_cli("What does test.txt say?",
            working_directory: dir)
          
          assert result[:success]
          assert_match(/ruby.*awesome/i, result[:stdout])
        end
      end
      
      # Expensive test (skipped by default)
      def test_long_response
        skip "Set RUN_EXPENSIVE=true to run" unless ENV["RUN_EXPENSIVE"]
        
        result = run_auto_claude_cli("Write 500 words about Ruby")
        
        assert result[:success]
        word_count = result[:stdout].split.count
        assert word_count >= 400, "Expected 400+ words, got #{word_count}"
      end
    end
  end
end
```

## Contributing

When adding new integration tests:

1. Follow the existing patterns in `test/integration/`
2. Ensure tests are skipped without `INTEGRATION=true`
3. Use fuzzy matching for AI responses
4. Document any special requirements
5. Clean up any resources created
6. Consider API costs when designing tests

## Summary

The integration test framework provides a robust way to test auto-claude with real Claude API calls while managing the challenges of non-deterministic AI output, API costs, and execution time. By following the patterns and best practices outlined here, you can write effective integration tests that verify end-to-end functionality without brittle assertions or excessive API consumption.