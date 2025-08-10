#!/usr/bin/env ruby

# Advanced features of auto-claude gem
# Shows callbacks, session metadata, and real-time message handling

require 'auto_claude'

# =============================================================================
# 1. Real-time message callbacks
# =============================================================================
puts "1. Real-time message callbacks"
puts "=" * 60

client = AutoClaude::Client.new

# Track messages as they arrive
messages_received = []

session = client.run("Count from 1 to 3, then say 'done'") do |message|
  # This callback is called for each message as it arrives
  case message
  when AutoClaude::Messages::TextMessage
    puts "  [Assistant]: #{message.text}"
    messages_received << message.text
  when AutoClaude::Messages::ToolUseMessage
    puts "  [Tool Use]: #{message.tool_name}(#{message.tool_input})"
  when AutoClaude::Messages::ToolResultMessage
    puts "  [Tool Result]: #{message.output[0..100]}..." if message.output.length > 100
  when AutoClaude::Messages::ResultMessage
    puts "  [Complete]: Success=#{message.success?}"
  end
end

puts "\nTotal messages received: #{messages_received.count}"
puts "Final result: #{session.result.content}"
puts

# =============================================================================
# 2. Session metadata and statistics
# =============================================================================
puts "2. Session metadata and statistics"
puts "=" * 60

client = AutoClaude::Client.new
session = client.run("Write a haiku about programming")

puts "Session Statistics:"
puts "  Success: #{session.success?}"
puts "  Session ID: #{session.session_id}"
puts "  Duration: #{'%.2f' % session.duration} seconds"
puts "  Cost: $#{'%.6f' % session.cost}"
puts "  Tokens: #{session.token_usage[:input]} input, #{session.token_usage[:output]} output"
puts "  Metadata: #{session.metadata.inspect}"
puts

# =============================================================================
# 3. Async execution
# =============================================================================
puts "3. Async execution"
puts "=" * 60

client = AutoClaude::Client.new

# Start multiple async sessions
puts "Starting 3 async sessions..."
threads = [
  client.run_async("What is the color of the sky?"),
  client.run_async("What is 2 + 2?"),
  client.run_async("Name a programming language")
]

# Do other work while they run...
puts "Doing other work while Claude processes..."
sleep 0.1

# Wait for all to complete and get results
sessions = threads.map(&:value)

sessions.each_with_index do |session, i|
  puts "  Session #{i+1}: #{session.result.content}"
end
puts

# =============================================================================
# 4. Logging to file while displaying to terminal
# =============================================================================
puts "4. Logging to file"
puts "=" * 60

require 'tempfile'

# Create a temporary log file
log_file = Tempfile.new(['claude_log', '.txt'])

# Create outputs
file_output = AutoClaude::Output::File.new(log_file.path)
terminal_output = AutoClaude::Output::Terminal.new

# Multiplex to both
multi_output = AutoClaude::Output::Multiplexer.new([terminal_output, file_output])

client = AutoClaude::Client.new(output: multi_output)
session = client.run("Say 'Hello, this is being logged!'")

# Save metadata to log
file_output.write_metadata(session.metadata)
file_output.close

puts "\nLog file contents:"
puts File.read(log_file.path)
log_file.unlink
puts

# =============================================================================
# 5. Memory output for capturing everything
# =============================================================================
puts "5. Memory output for testing/debugging"
puts "=" * 60

memory_output = AutoClaude::Output::Memory.new
client = AutoClaude::Client.new(output: memory_output)

session = client.run("What is Ruby?")

puts "Captured in memory:"
puts "  Messages: #{memory_output.messages.count}"
puts "  User messages: #{memory_output.user_messages.join(', ')}"
puts "  Stats: #{memory_output.stats.inspect}"
puts "  Errors: #{memory_output.errors.inspect}"
puts "  Info: #{memory_output.info.inspect}"
puts

# =============================================================================
# 6. Progress tracking with callbacks
# =============================================================================
puts "6. Progress tracking"
puts "=" * 60

client = AutoClaude::Client.new

# Simple progress indicator
step_count = 0

session = client.run("List 3 benefits of test-driven development") do |message|
  if message.is_a?(AutoClaude::Messages::TextMessage)
    step_count += 1
    print "\r  Processing step #{step_count}..."
  end
end

puts "\r  Completed #{step_count} steps!"
puts "  Result: #{session.result.content[0..200]}..."
puts

# =============================================================================
# 7. Working with specific directories
# =============================================================================
puts "7. Working with specific directories"
puts "=" * 60

require 'tmpdir'

Dir.mktmpdir do |tmpdir|
  # Create a test file
  File.write(File.join(tmpdir, "test.txt"), "Hello from test file!")
  
  # Run Claude in that directory
  client = AutoClaude::Client.new(directory: tmpdir)
  session = client.run("What files are in the current directory?")
  
  puts "Working in: #{tmpdir}"
  puts "Claude found: #{session.result.content}"
end