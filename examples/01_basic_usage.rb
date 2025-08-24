#!/usr/bin/env ruby
# frozen_string_literal: true

# Basic usage examples for auto-claude gem
# Shows the simplest ways to use the Client API

require "auto_claude"

# =============================================================================
# 1. Simplest usage - quick question
# =============================================================================
puts "1. Simple question"
puts "=" * 60

client = AutoClaude::Client.new
session = client.run("What is 2 + 2?")

if session.success?
  puts "Answer: #{session.result.content}"
else
  puts "Error: #{session.result.error_message}"
end
puts

# =============================================================================
# 2. Using different Claude models
# =============================================================================
puts "2. Different Claude models"
puts "=" * 60

# Use Haiku (fast, economical)
haiku_client = AutoClaude::Client.new(claude_options: ["--model", "haiku"])
haiku_session = haiku_client.run("What is the capital of France?")
puts "Haiku says: #{haiku_session.result.content}"

# Use Sonnet (balanced)
sonnet_client = AutoClaude::Client.new(claude_options: ["--model", "sonnet"])
sonnet_session = sonnet_client.run("What is the capital of Japan?")
puts "Sonnet says: #{sonnet_session.result.content}"
puts

# =============================================================================
# 3. Working in a specific directory
# =============================================================================
puts "3. Working directory"
puts "=" * 60

require "tmpdir"

Dir.mktmpdir do |tmpdir|
  # Create some test files
  File.write(File.join(tmpdir, "hello.txt"), "Hello World!")
  File.write(File.join(tmpdir, "data.json"), '{"name": "test", "value": 42}')
  
  # Run Claude in that directory
  client = AutoClaude::Client.new(directory: tmpdir)
  session = client.run("List all files in the current directory and show the contents of hello.txt")
  
  puts "Working in: #{tmpdir}"
  puts "Claude says: #{session.result.content}"
end
puts

# =============================================================================
# 4. Getting session statistics
# =============================================================================
puts "4. Session statistics"
puts "=" * 60

client = AutoClaude::Client.new
session = client.run("Write a haiku about Ruby programming")

if session.success?
  puts "Haiku: #{session.result.content}"
  puts "\nSession details:"
  puts "  Session ID: #{session.session_id}"
  puts "  Duration: #{"%.2f" % session.duration} seconds"
  puts "  Input tokens: #{session.input_tokens}"
  puts "  Output tokens: #{session.output_tokens}"
  puts "  Total cost: $#{"%.6f" % session.cost}"
end
puts

# =============================================================================
# 5. Error handling
# =============================================================================
puts "5. Error handling"
puts "=" * 60

client = AutoClaude::Client.new

# This might fail if there are rate limits or other issues
session = client.run("What is the weather today?")

if session.success?
  puts "Success: #{session.result.content}"
else
  puts "Failed!"
  puts "  Error: #{session.result.error_message}"
  puts "  Exit code: #{session.result.exit_code}"
  
  # You could retry with different options or handle the error
  if session.result.exit_code == 1
    puts "  This might be a temporary issue, consider retrying..."
  end
end
puts

# =============================================================================
# 6. Using callbacks to monitor progress
# =============================================================================
puts "6. Progress monitoring with callbacks"
puts "=" * 60

client = AutoClaude::Client.new

puts "Asking Claude to count..."
message_count = 0

session = client.run("Count from 1 to 5 slowly") do |message|
  # This callback is called for each message as it arrives
  if message.is_a?(AutoClaude::Messages::TextMessage)
    message_count += 1
    print "."
  end
end

puts "\nReceived #{message_count} messages"
puts "Final result: #{session.result.content}"
puts

# =============================================================================
# 7. Silent operation (no terminal output)
# =============================================================================
puts "7. Silent operation"
puts "=" * 60

# Use memory output to capture everything without printing
memory_output = AutoClaude::Output::Memory.new
client = AutoClaude::Client.new(output: memory_output)

puts "Running silently..."
session = client.run("What is Ruby?")

puts "Captured silently:"
puts "  Result: #{session.result.content[0..100]}..."
puts "  Messages captured: #{memory_output.messages.count}"
puts

# =============================================================================
# 8. Passing multiple Claude options
# =============================================================================
puts "8. Multiple Claude options"
puts "=" * 60

client = AutoClaude::Client.new(
  claude_options: [
    "--model", "haiku",
    "--max-tokens", "50",
    "--temperature", "0.5"
  ]
)

session = client.run("Explain quantum computing in one sentence")
puts "Concise explanation: #{session.result.content}"