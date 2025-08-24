# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

auto-claude is a Ruby CLI tool that wraps the Claude CLI to provide non-interactive execution with elegant streaming output formatting. It serves as both a command-line tool and a Ruby library for programmatic usage.

## Development Commands

### Testing
```bash
# Run all tests (254 tests with 780+ assertions)
rake test

# Run a specific test file
ruby -Itest:lib test/auto_claude/client_test.rb

# Run a specific test method
ruby -Itest:lib test/auto_claude/output/formatter_test.rb -n test_format_todo_list

# Run tests with verbose output
rake test TESTOPTS="-v"

# Run tests matching a pattern
rake test TEST="test/auto_claude/output/formatters/*_test.rb"
```

### Linting
```bash
# Run RuboCop to check code style
rake rubocop
# or
bundle exec rubocop

# Auto-fix safe violations
rake rubocop:autocorrect

# Auto-fix all violations (safe and unsafe)
rake rubocop:autocorrect_all
# or
bundle exec rubocop -A

# Check specific files or directories
bundle exec rubocop lib/auto_claude/output/

# Generate offense summary
bundle exec rubocop --format offenses

# Run tests and linting together (default task)
rake
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

### Core Components

**AutoClaude::CLI** (`lib/auto_claude/cli.rb`): Main command-line interface using Thor framework. Handles argument parsing and validation. Key features:
- Custom argument parsing to split auto-claude options from claude options (separated by `--`)
- Retry logic with `--resume` support for error recovery
- Creates and manages Client instances for execution

**AutoClaude::Client** (`lib/auto_claude/client.rb`): Primary API for running Claude sessions programmatically. Features:
- Session management and metadata tracking
- Callback support for real-time message processing
- Flexible output handling (terminal, file, memory, multiplexed)

**AutoClaude::Process::Manager** (`lib/auto_claude/process/manager.rb`): Executes the Claude CLI command with streaming JSON output parsing. Manages:
- Process spawning with Open3
- Working directory isolation
- JSON stream processing and error handling
- Session metadata extraction for resume functionality

**AutoClaude::Output::Formatter** (`lib/auto_claude/output/formatter.rb`): Main formatter orchestrator that delegates to specialized formatters based on message type. Recently refactored from a 500+ line monolithic class into a modular architecture with:
- FormatterRegistry for managing specialized formatters
- FormatterConfig for centralized configuration
- 8 specialized formatters (Bash, File, Search, Web, Task, Todo, MCP, etc.)
- Helper classes for text truncation, link parsing, and result formatting

**Output System** (`lib/auto_claude/output/`): Modular output system supporting multiple targets:
- `Terminal`: Colored terminal output with emoji indicators
- `File`: JSON logging to files
- `Memory`: In-memory buffering for programmatic usage
- `Writer`: Base class for output implementations

### Formatter Architecture

The formatter system follows a modular design after recent refactoring:

1. **FormatterConfig** (`formatter_config.rb`): Centralized configuration with constants:
   - `STANDARD_INDENT = 8`: Consistent indentation for multi-line content
   - `MAX_PREVIEW_LINES = 5`: Default lines to show in previews
   - Tool and message emojis
   - Filtered message prefixes

2. **Specialized Formatters** in `formatters/`:
   - Each formatter handles specific tool types (File, Search, Web, etc.)
   - All inherit from `Base` formatter
   - Consistent 8-space indentation for subordinate content

3. **Helper Classes** in `helpers/`:
   - `TextTruncator`: Smart text truncation with ellipsis
   - `LinkParser`: Extracts and formats links from content
   - `ResultFormatter`: Handles multi-line result formatting with smart indentation

### Key Design Patterns

1. **Command Separation**: Arguments after `--` are passed directly to the Claude CLI, allowing full access to Claude's options while maintaining auto-claude's formatting layer.

2. **Streaming Processing**: JSON messages from Claude are parsed and formatted in real-time as they stream, providing immediate feedback to users.

3. **Error Recovery**: Built-in retry mechanism using Claude's `--resume` functionality to recover from transient failures.

4. **Dual Interface**: Designed for both CLI usage (`auto-claude` command) and programmatic Ruby usage (`AutoClaude::Client.new.run()`).

## Ruby Dependencies

The project uses:
- `thor` - CLI framework
- `zeitwerk` - Automatic code loading
- `activesupport` - Ruby utilities
- `minitest` - Testing framework
- `rake` - Build automation