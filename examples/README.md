# AutoClaude Ruby Examples

This directory contains examples demonstrating how to use the auto-claude gem in Ruby applications.

## Examples Overview

### 01_basic_usage.rb
Getting started with auto-claude
- Simple questions and answers
- Using different Claude models (Haiku, Sonnet)
- Working in specific directories
- Session statistics and costs
- Error handling
- Progress monitoring with callbacks
- Silent operation with memory output

### 02_advanced_features.rb
Advanced features for production applications
- Real-time message callbacks and tracking
- Session metadata and token usage
- Concurrent execution with threads
- File logging with multiplexed output
- Memory output for testing/debugging
- Progress tracking with different message types
- Directory-specific operations
- Session resume capability

### 04_concurrent_sessions.rb
Parallel and concurrent execution patterns
- Simple concurrent execution
- Parallel processing of lists
- Thread pool pattern for batch processing
- Producer-consumer pattern with queues
- Thread-safe callbacks with Mutex
- Mixed task types running concurrently
- Error handling in concurrent operations

### 05_custom_output.rb
Custom output handling and formatting
- Memory output for capturing everything
- File logging with size tracking
- Multiplexed output (terminal + file + memory)
- Custom filtered output writers
- JSON structured logging
- Webhook/streaming simulation
- Silent operation with null output
- Pretty output with emojis

## Running the Examples

Each example is a standalone Ruby script that can be run directly:

```bash
# From the project root, install dependencies
bundle install

# Run examples using bundler
bundle exec ruby examples/01_basic_usage.rb
bundle exec ruby examples/02_advanced_features.rb
bundle exec ruby examples/04_concurrent_sessions.rb
bundle exec ruby examples/05_custom_output.rb

# Or if you have the gem installed globally
gem install auto_claude
ruby examples/01_basic_usage.rb
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
  puts "Cost: $#{session.cost}"  # Track API costs
end

# With specific model and directory
client = AutoClaude::Client.new(
  claude_options: ["--model", "haiku"],  # Use Haiku model
  directory: "/path/to/project"           # Run in specific directory
)

session = client.run("List files here")
puts session.result.content if session.success?
```

## Key Features

1. **Client Interface**: Full-featured Client API with session management and callbacks

2. **Concurrent Execution**: Run multiple Claude sessions in parallel using Ruby threads

3. **Flexible Output**: Capture output to memory, files, or create custom output handlers

4. **Working Directory Support**: Run Claude in any directory for file operations

5. **Real-time Callbacks**: Process messages as they stream for progress tracking

6. **Session Tracking**: Monitor costs, token usage, duration, and success status

7. **Custom Formatters**: Create specialized output formats (JSON, webhooks, pretty print)

8. **Error Recovery**: Handle failures gracefully with session resume capability

## Best Practices

1. **Always check session.success?** before using the result

2. **Use Thread-safe code** when running concurrent sessions (see Mutex examples)

3. **Monitor costs** with `session.cost` and token usage for budget tracking

4. **Use memory output** for testing to avoid console output in test suites

5. **Batch concurrent requests** to avoid overwhelming the API (see thread pool example)

6. **Set working directory** when Claude needs to access specific files

7. **Handle rate limits** gracefully with error handling and retries

8. **Use appropriate models**: Haiku for speed/cost, Sonnet for balance, Opus for complex tasks

## Example Use Cases

- **Batch Processing**: Process multiple prompts concurrently (see concurrent examples)
- **Testing Integration**: Use memory output to capture Claude responses in tests
- **Logging & Monitoring**: Use file output or JSON formatting for audit trails
- **CI/CD Integration**: Run Claude silently with null output, check exit status
- **Custom Tooling**: Build specialized outputs for your workflow

## Need Help?

- Check the main [README](../README.md) for installation and setup
- See [CLAUDE.md](../CLAUDE.md) for architecture and development details
- Run tests with `rake test` to verify your setup
- Report issues at https://github.com/juniperab/auto-claude/issues