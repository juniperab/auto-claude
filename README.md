# auto-claude

A Ruby CLI tool and library that wraps the Claude Code CLI to provide non-interactive execution with elegant streaming output formatting.

## Features

- 🚀 Non-interactive execution of prompts with Claude Code CLI
- 🎨 Real-time streaming output with color formatting and emojis
- 📝 Specialized formatters for different tool types (bash, file operations, search, web, todos)
- 📁 Working directory support - run Claude in any directory
- 🔄 Automatic retry for failed prompts using session resume functionality
- 💎 Ruby API for programmatic usage
- 🧪 Comprehensive test suite with unit and integration tests

## Prerequisites

- Ruby 3.4.0 or higher
- Claude CLI installed and available in PATH
- Valid Claude API credentials configured

## Installation

### From source

```bash
# Clone the repository
git clone https://github.com/juniperab/auto-claude.git
cd auto-claude

# Install dependencies
bundle install

# Build and install the gem
gem build auto_claude.gemspec
gem install ./auto_claude-*.gem
```

## Usage

### Command Line

```bash
# Basic usage
auto-claude "What is 2+2?"

# Read prompt from stdin
echo "Explain Ruby blocks" | auto-claude

# Specify working directory
auto-claude -d /path/to/project "List the files here"

# Log output to a file
auto-claude -l output.log "Your prompt"
auto-claude --log session.txt "Explain recursion"

# Pass options to Claude Code CLI (after --)
auto-claude "Write a haiku" -- --model haiku --temperature 0.7

# Automatically retry if Claude fails while executing a prompt
auto-claude -r "Your prompt"
```

### Ruby API

```ruby
require 'auto_claude'

# Create a client
client = AutoClaude::Client.new(
  directory: "/path/to/work",
  claude_options: ["--model", "sonnet"],
  output: AutoClaude::Output::Terminal.new
)

# Run with a prompt
session = client.run("Explain the code in this directory") do |message|
  # Optional: process messages as they stream
  puts "Received: #{message.type}"
end

# Check results
if session.success?
  puts session.result.content
  puts "Tokens used: #{session.input_tokens} in, #{session.output_tokens} out"
  puts "Cost: $#{session.cost}"
end
```

## Testing

```bash
# Run unit tests only (fast, mocked responses)
rake test

# Run integration tests (real Claude API calls)
rake test:integration

# Run all tests
rake test:all

# Run code style checks
rake rubocop

# Auto-fix style violations
rake rubocop:autocorrect
```

**Unit tests** mock the Claude CLI subprocess to test formatting, parsing, and business logic without making API calls.

**Integration tests** make real Claude API calls and run in isolated temporary directories for security. They require Claude CLI to be installed and configured. See [test/integration/README.md](test/integration/README.md) for details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
