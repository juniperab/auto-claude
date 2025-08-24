# auto-claude

A Ruby CLI tool and library that wraps the Claude CLI to provide non-interactive execution with elegant streaming output formatting.

## Features

- 🚀 Non-interactive execution of Claude commands
- 🎨 Real-time streaming output with color formatting and emojis
- 📝 Specialized formatters for different tool types (bash, file operations, search, web, todos)
- 📁 Working directory support - run Claude in any directory
- 🔄 Session resume capability for retrying failed commands
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

# Pass options to Claude CLI (after --)
auto-claude "Write a haiku" -- --model haiku --temperature 0.7

# Resume a failed session
auto-claude --resume

# Save output to file
auto-claude -o output.txt "Your prompt"
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

## Development

See [CLAUDE.md](CLAUDE.md) for detailed development instructions, architecture overview, and debugging tips.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for your changes
4. Ensure all tests pass (`rake test:all`)
5. Run RuboCop (`rake rubocop:autocorrect`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
