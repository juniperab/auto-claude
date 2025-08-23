# AutoClaude Ruby Examples

This directory contains examples demonstrating how to use the auto-claude gem in Ruby applications.

## Examples Overview

### 02_advanced_features.rb
Advanced features for production applications.
- Real-time message callbacks
- Session metadata and statistics
- Async execution
- File logging with multiplexed output
- Memory output for testing/debugging
- Progress tracking
- Directory-specific operations

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

## Running the Examples

Each example is a standalone Ruby script that can be run directly:

```bash
# Make sure you have the gem installed
gem install auto_claude

# Or if using bundler, add to Gemfile:
# gem 'auto_claude'

# Run an example
ruby examples/02_advanced_features.rb
```

## Quick Start

The simplest way to use auto-claude in your Ruby application:

```ruby
require 'auto_claude'

# Create a client
client = AutoClaude::Client.new

# Run a prompt
session = client.run("What is 2+2?")

# Get the result
if session.success?
  puts session.result.content  # "4"
end

# With options
client = AutoClaude::Client.new(
  claude_options: ["--model", "claude-3-5-sonnet-20241022"]
)
session = client.run("Explain Ruby")
puts session.result.content if session.success?
```

## Key Features

1. **Client Interface**: Full-featured Client interface with session management

2. **Concurrent Execution**: Run multiple Claude sessions in parallel for better performance

3. **Flexible Output**: Capture output to memory, files, or create custom output handlers

4. **Robust Error Handling**: Detect and handle errors gracefully

5. **Real-time Callbacks**: Process messages as they arrive for progress tracking or streaming

6. **Session Management**: Access metadata, track costs and token usage

## Best Practices

1. **Always check session.success?** before using the result

2. **Handle errors gracefully** - Claude sessions can fail due to rate limits, network issues, or other problems

3. **Use concurrent execution** when processing multiple independent tasks

4. **Monitor costs** using session metadata, especially for high-volume applications

5. **Use memory output** for testing to avoid console output in test suites

## Need Help?

- Check the main [README](../README.md) for installation and setup
- See [CLAUDE.md](../CLAUDE.md) for implementation details
- Report issues at https://github.com/juniperab/auto-claude/issues