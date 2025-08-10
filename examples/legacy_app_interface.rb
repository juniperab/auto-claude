#!/usr/bin/env ruby

# Example of using auto-claude as a gem in a Ruby application

require 'stringio'
require_relative 'lib/auto_claude'

# Example 1: Basic usage
puts "Example 1: Basic usage"
puts "-" * 50
result = AutoClaude::App.run("What is 2+2?")
puts "Result: #{result}"
puts

# Example 2: With directory option
puts "Example 2: With directory option"
puts "-" * 50
result = AutoClaude::App.run(
  "List files",
  directory: "/tmp"
)
puts "Result: #{result}"
puts

# Example 3: With logging
puts "Example 3: With logging"
puts "-" * 50
result = AutoClaude::App.run(
  "Tell me about Ruby",
  log_file: "/tmp/claude_test.log"
)
puts "Result: #{result}"
puts

# Example 4: With claude options
puts "Example 4: With claude options"
puts "-" * 50
result = AutoClaude::App.run(
  "What language is this code written in?",
  claude_options: ["--no-cache"]
)
puts "Result: #{result}"
puts

# Example 5: Capturing output to StringIO
puts "Example 5: Capturing output to StringIO"
puts "-" * 50
output = StringIO.new
error = StringIO.new
result = AutoClaude::App.run(
  "Hello Claude",
  output: output,
  error: error
)
puts "Result: #{result}"
puts "Captured output: #{output.string}"
puts "Captured error: #{error.string}"
puts

# Example 6: Error handling
puts "Example 6: Error handling"
puts "-" * 50
begin
  result = AutoClaude::App.run(
    "Test",
    claude_options: ["--verbose"] # This should raise an error
  )
rescue => e
  puts "Caught expected error: #{e.message}"
end
puts

# Example 7: Live streaming stderr callback
puts "Example 7: Live streaming stderr callback"
puts "-" * 50
puts "Running with live stderr streaming:"
result = AutoClaude::App.run(
  "Write a simple hello world function",
  stderr_callback: -> (msg, type, color) { 
    # In a real application, you could:
    # - Update a UI progress indicator
    # - Stream to a websocket
    # - Log to a different system
    # - Filter specific message types
    print "[STREAM][#{type}][#{color}] #{msg}"
  }
)
puts "\nResult: #{result}"
puts

# Example 8: Filtering stderr messages by type
puts "Example 8: Filtering stderr messages by type"
puts "-" * 50
stat_messages = []
other_messages = []

result = AutoClaude::App.run(
  "What is the capital of France?",
  stderr_callback: -> (msg, type, color) { 
    if type == :stat
      stat_messages << msg.strip
    else
      other_messages << msg.strip
    end
  }
)

puts "Stat messages captured: #{stat_messages.count}"
puts "Other messages captured: #{other_messages.count}"
puts "Result: #{result}"