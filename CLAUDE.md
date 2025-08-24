# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

auto-claude is a Ruby CLI tool that wraps the Claude CLI to provide non-interactive execution with elegant streaming output formatting. It serves as both a command-line tool and a Ruby library for programmatic usage.

## Development Commands

### Testing
```bash
# Run unit tests only (mocked Claude responses, ~251 tests)
rake test

# Run integration tests (real Claude API calls)
rake test:integration

# Run all tests
rake test:all

# Run a specific test file
ruby -Itest:lib test/auto_claude/client_test.rb

# Run a specific test method
ruby -Itest:lib test/auto_claude/output/formatter_test.rb -n test_format_todo_list

# Run integration test with debug output
DEBUG=true INTEGRATION=true ruby -Itest:lib test/integration/basic_claude_test.rb

# Run tests matching a pattern
rake test TEST="test/auto_claude/output/formatters/*_test.rb"
```

### Linting and Code Style
```bash
# Default task: run tests and RuboCop
rake

# Run RuboCop only
rake rubocop

# Auto-fix RuboCop violations
rake rubocop:autocorrect

# Check specific files or directories
bundle exec rubocop lib/auto_claude/output/
```

### Building and Installing
```bash
# Install dependencies
bundle install

# Build the gem
gem build auto_claude.gemspec

# Install locally for testing
gem install ./auto_claude-*.gem

# Run from source without installing
bundle exec ruby -Ilib exe/auto-claude "your prompt"
```

### Debugging
```bash
# Enable raw message display (shows JSON messages before formatting)
AUTOCLAUDE_SHOW_RAW_MESSAGES=160 auto-claude "prompt"

# Disable output filtering (shows all messages including filtered ones)
AUTOCLAUDE_DISABLE_FILTERS=1 auto-claude "prompt"
```

## Architecture

### Core Flow
1. **CLI Entry** (`lib/auto_claude/cli.rb`) → Parses arguments, separates auto-claude options from Claude options (after `--`)
2. **Client** (`lib/auto_claude/client.rb`) → Manages sessions, callbacks, and output routing
3. **Process Manager** (`lib/auto_claude/process/manager.rb`) → Creates shell script wrapper, spawns Claude process with `Open3.popen3`
4. **Stream Parser** → Parses streaming JSON from Claude into message objects
5. **Formatter System** → Routes messages to specialized formatters based on tool type
6. **Output Writers** → Sends formatted output to terminal, file, or memory

### Testing Strategy

**Unit Tests** (`test/auto_claude/`):
- All tests mock `Open3.popen3` to avoid calling real Claude CLI
- Test business logic: formatting, parsing, session management
- Fast and deterministic

**Integration Tests** (`test/integration/`):
- Make real Claude API calls
- **Always run in isolated temp directories** - Claude never accesses project directory
- Use fuzzy matching for non-deterministic AI output
- Run with `rake test:integration` or `INTEGRATION=true`

### Formatter System

The formatter system (`lib/auto_claude/output/`) uses a registry pattern to route messages to specialized formatters:

- **FormatterConfig**: Central constants including `STANDARD_INDENT = 8` for consistent indentation
- **Specialized Formatters** (`formatters/`): Each handles specific tool types (Bash, File, Search, Web, Task, Todo, MCP)
- **Helper Classes** (`helpers/`): TextTruncator, LinkParser, ResultFormatter for common formatting tasks

All formatters follow the pattern of 8-space indentation for subordinate content to maintain visual hierarchy.

### Key Implementation Details

- **Message Parsing**: All Claude JSON responses are parsed into message objects (`lib/auto_claude/messages/`)
- **Working Directory**: The `-d` option sets Claude's working directory via a shell script wrapper
- **Process Isolation**: Integration tests always run Claude in temp directories, never in the project directory
- **Streaming**: Uses `Open3.popen3` to stream and parse Claude's JSON output line-by-line
- **Error Recovery**: Supports `--resume` flag to retry failed Claude sessions

### Ruby API Usage

```ruby
require 'auto_claude'

# Create client with options
client = AutoClaude::Client.new(
  directory: "/path/to/work",
  claude_options: ["--model", "sonnet"],
  output: AutoClaude::Output::Memory.new
)

# Run with callback
session = client.run("Your prompt") do |message|
  puts "Received: #{message.type}"
end

# Check results
if session.success?
  puts session.result.content
  puts "Cost: #{session.cost}"
end
```