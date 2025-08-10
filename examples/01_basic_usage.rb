#!/usr/bin/env ruby

# Basic usage examples for auto-claude gem
# Shows the simplest ways to use the library

require 'auto_claude'

# =============================================================================
# Method 1: Module-level convenience method (simplest)
# =============================================================================
puts "1. Module-level convenience method"
puts "=" * 60

result = AutoClaude.run("What is 2+2?")
puts "Result: #{result}"
puts

# =============================================================================
# Method 2: App.run for backward compatibility
# =============================================================================
puts "2. App.run method (backward compatible)"
puts "=" * 60

result = AutoClaude::App.run(
  "What is the capital of France?",
  directory: "/tmp"  # Optional: run in specific directory
)
puts "Result: #{result}"
puts

# =============================================================================
# Method 3: Client interface (recommended for new code)
# =============================================================================
puts "3. Client interface (recommended)"
puts "=" * 60

# Create a client
client = AutoClaude::Client.new

# Run a simple command
session = client.run("List the primary colors")

# Access the result
if session.success?
  puts "Result: #{session.result.content}"
  puts "Session ID: #{session.session_id}"
  puts "Cost: $#{'%.6f' % session.cost}" if session.cost > 0
else
  puts "Error: #{session.result.error_message}"
end
puts

# =============================================================================
# Method 4: Client with custom directory
# =============================================================================
puts "4. Client with custom directory"
puts "=" * 60

client = AutoClaude::Client.new(directory: "/tmp")
session = client.run("What directory am I in?")

puts "Result: #{session.result.content}"
puts

# =============================================================================
# Method 5: Passing options to Claude
# =============================================================================
puts "5. Passing Claude options"
puts "=" * 60

# With module method
result = AutoClaude.run(
  "Be very brief: what is Ruby?",
  claude_options: ["--model", "claude-3-5-sonnet-20241022"]
)
puts "Module result: #{result}"
puts

# With client
client = AutoClaude::Client.new(
  claude_options: ["--model", "claude-3-5-sonnet-20241022"]
)
session = client.run("Be very brief: what is Python?")
puts "Client result: #{session.result.content}"
puts

# =============================================================================
# Method 6: Multiple prompts with same client
# =============================================================================
puts "6. Multiple prompts with same client"
puts "=" * 60

client = AutoClaude::Client.new

# Run multiple independent sessions
session1 = client.run("What is 10 + 20?")
session2 = client.run("What is 100 - 30?")
session3 = client.run("What is 5 * 6?")

puts "Results:"
puts "  10 + 20 = #{session1.result.content}"
puts "  100 - 30 = #{session2.result.content}"
puts "  5 * 6 = #{session3.result.content}"
puts "Total sessions: #{client.sessions.count}"