# AutoClaude Ruby Examples

This directory contains examples demonstrating how to use the auto-claude gem in Ruby applications.

## Examples Overview

### 01_basic_usage.rb
Introduction to using auto-claude in Ruby applications.
- Module-level convenience method (`AutoClaude.run`)
- Backward-compatible `App.run` interface
- Modern `Client` interface (recommended)
- Working with different directories
- Passing options to Claude
- Running multiple sessions

### 02_advanced_features.rb
Advanced features for production applications.
- Real-time message callbacks
- Session metadata and statistics
- Async execution
- File logging with multiplexed output
- Memory output for testing/debugging
- Progress tracking
- Directory-specific operations

### 03_error_handling.rb
Robust error handling strategies.
- Error detection and recovery
- Exception handling
- Automatic retry with `retry_on_error`
- Manual retry logic
- Timeout handling
- Fallback responses
- Batch operations with error collection
- Debugging with session information

### 04_concurrent_sessions.rb
Parallel and concurrent execution patterns.
- Simple concurrent execution
- Parallel processing of lists
- Thread pool pattern for batch processing
- Producer-consumer pattern
- Real-time callbacks with async
- Mixed task types
- Error handling in concurrent operations

### 05_custom_output.rb
Custom output handling and formatting.
- Memory output for testing
- File logging
- Multiplexed output (terminal + file + memory)
- Custom output writers
- JSON formatting
- Streaming to external services
- Silent operation
- Custom formatted output with emojis

### 06_retry_and_resume.rb
Retry strategies and session resumption.
- Basic retry with `App.run`
- Manual retry with session resumption
- Continuing specific sessions
- Exponential backoff
- Different retry strategies
- Partial failure handling
- Session chaining with retry

### legacy_app_interface.rb
Legacy examples using the older App.run interface. Kept for reference but new code should use the Client interface shown in the other examples.

## Running the Examples

Each example is a standalone Ruby script that can be run directly:

```bash
# Make sure you have the gem installed
gem install auto_claude

# Or if using bundler, add to Gemfile:
# gem 'auto_claude'

# Run an example
ruby examples/01_basic_usage.rb
```

## Quick Start

The simplest way to use auto-claude in your Ruby application:

```ruby
require 'auto_claude'

# Simplest usage
result = AutoClaude.run("What is 2+2?")
puts result  # "4"

# With options
result = AutoClaude.run(
  "Explain Ruby",
  claude_options: ["--model", "claude-3-5-sonnet-20241022"]
)

# Using the Client interface (recommended)
client = AutoClaude::Client.new
session = client.run("Hello Claude!")
puts session.result.content if session.success?
```

## Key Features

1. **Multiple Interfaces**: Choose between simple module methods, backward-compatible App.run, or the full-featured Client interface

2. **Concurrent Execution**: Run multiple Claude sessions in parallel for better performance

3. **Flexible Output**: Capture output to memory, files, or create custom output handlers

4. **Robust Error Handling**: Automatic retry with session resumption, exponential backoff, and fallback strategies

5. **Real-time Callbacks**: Process messages as they arrive for progress tracking or streaming

6. **Session Management**: Continue conversations, access metadata, track costs and token usage

## Best Practices

1. **Use the Client interface** for new applications - it provides the most features and flexibility

2. **Handle errors gracefully** - Claude sessions can fail due to rate limits, network issues, or other problems

3. **Use concurrent execution** when processing multiple independent tasks

4. **Implement retry logic** for production applications to handle transient failures

5. **Monitor costs** using session metadata, especially for high-volume applications

6. **Use memory output** for testing to avoid console output in test suites

## Need Help?

- Check the main [README](../README.md) for installation and setup
- See [CLAUDE.md](../CLAUDE.md) for implementation details
- Report issues at https://github.com/juniperab/auto-claude/issues