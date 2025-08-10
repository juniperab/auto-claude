# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

auto-claude is a Ruby CLI tool that wraps the Claude CLI to provide non-interactive execution with elegant streaming output formatting. It serves as both a command-line tool and a Ruby library for programmatic usage.

## Development Commands

### Testing
```bash
# Run all tests
rake test

# Run a specific test file
ruby -Itest:lib test/auto_claude/app_test.rb

# Run tests with verbose output
rake test TESTOPTS="-v"
```

### Building and Installing
```bash
# Install dependencies
bundle install

# Build the gem
gem build auto_claude.gemspec

# Install locally for testing
gem install ./auto_claude-*.gem
```

## Architecture

### Core Components

**AutoClaude::App** (`lib/auto_claude/app.rb`): Main application class using Thor framework. Handles command-line argument parsing, validation, and provides both CLI and programmatic interfaces. Key features:
- Custom argument parsing to split auto-claude options from claude options (separated by `--`)
- Retry logic with `--resume` support for error recovery
- Programmatic Ruby API via `App.run()` method

**AutoClaude::ClaudeRunner** (`lib/auto_claude/claude_runner.rb`): Executes the Claude CLI command with streaming JSON output parsing. Manages:
- Process spawning with Open3
- Working directory isolation
- JSON stream processing and error handling
- Session metadata extraction for resume functionality

**AutoClaude::ColorPrinter** (`lib/auto_claude/color_printer.rb`): Handles formatted output with color coding for different message types. Features:
- Colored terminal output for different message types
- Log file support with raw JSON logging
- Stderr callback mechanism for programmatic usage

**AutoClaude::MessageFormatter** (`lib/auto_claude/message_formatter.rb`): Formats Claude's JSON messages into human-readable output with proper markdown rendering and code block handling.

### Key Design Patterns

1. **Command Separation**: Arguments after `--` are passed directly to the Claude CLI, allowing full access to Claude's options while maintaining auto-claude's formatting layer.

2. **Streaming Processing**: JSON messages from Claude are parsed and formatted in real-time as they stream, providing immediate feedback to users.

3. **Error Recovery**: Built-in retry mechanism using Claude's `--resume` functionality to recover from transient failures.

4. **Dual Interface**: Designed for both CLI usage (`auto-claude` command) and programmatic Ruby usage (`AutoClaude::App.run()`).

## Ruby Dependencies

The project uses:
- `thor` - CLI framework
- `zeitwerk` - Automatic code loading
- `activesupport` - Ruby utilities
- `minitest` - Testing framework
- `rake` - Build automation