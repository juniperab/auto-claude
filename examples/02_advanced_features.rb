#!/usr/bin/env ruby
# frozen_string_literal: true

# Advanced features of auto-claude gem
# Shows callbacks, session metadata, async execution, and directory operations

require "auto_claude"

# =============================================================================
# 1. Real-time message callbacks
# =============================================================================
puts "1. Real-time message callbacks"
puts "=" * 60

client = AutoClaude::Client.new

# Track different types of messages as they arrive
text_messages = []
tool_uses = []

session = client.run("List 3 benefits of Ruby, then calculate 10 * 20") do |message|
  # This callback is called for each message as it arrives
  case message
  when AutoClaude::Messages::TextMessage
    text_messages << message.text
    puts "  [Text]: #{message.text[0..80]}..." if message.text.length > 80
  when AutoClaude::Messages::ToolUseMessage
    tool_uses << message.tool_name
    puts "  [Tool]: Using #{message.tool_name}"
  when AutoClaude::Messages::ToolResultMessage
    puts "  [Result]: Tool completed"
  when AutoClaude::Messages::ResultMessage
    puts "  [Final]: #{message.success? ? "Success" : "Failed"}"
  end
end

puts "\nMessage summary:"
puts "  Text messages: #{text_messages.count}"
puts "  Tool uses: #{tool_uses.uniq.join(", ") if tool_uses.any?}"
puts "  Final answer: #{session.result.content[0..100]}..."
puts

# =============================================================================
# 2. Session metadata and statistics
# =============================================================================
puts "2. Session metadata and statistics"
puts "=" * 60

client = AutoClaude::Client.new
session = client.run("Write a haiku about programming")

puts "Session Statistics:"
if session.success?
  puts "  Status: ✅ Success"
  puts "  Session ID: #{session.session_id}"
  puts "  Duration: #{"%.2f" % session.duration} seconds"
  puts "  Cost: $#{"%.6f" % session.cost}"
  puts "  Token usage:"
  puts "    Input: #{session.input_tokens} tokens"
  puts "    Output: #{session.output_tokens} tokens"
  puts "    Total: #{session.input_tokens + session.output_tokens} tokens"
  puts "  Model: #{session.metadata[:model] || "default"}"
else
  puts "  Status: ❌ Failed"
  puts "  Error: #{session.result.error_message}"
end
puts

# =============================================================================
# 3. Async execution
# =============================================================================
puts "3. Async execution"
puts "=" * 60

client = AutoClaude::Client.new

# Note: run_async returns a Thread object
puts "Starting 3 concurrent tasks..."

start_time = Time.now
threads = [
  Thread.new { client.run("What is the capital of France?") },
  Thread.new { client.run("What is 2 + 2?") },
  Thread.new { client.run("Name a programming language") }
]

# Wait for all to complete
sessions = threads.map(&:value)
end_time = Time.now

puts "  Completed in #{"%.2f" % (end_time - start_time)} seconds"
sessions.each_with_index do |session, i|
  puts "  Task #{i + 1}: #{session.result.content}"
end
puts

# =============================================================================
# 4. Logging to file while displaying to terminal
# =============================================================================
puts "4. Logging to file"
puts "=" * 60

require "tempfile"

# Create a temporary log file
log_file = Tempfile.new(["claude_log", ".txt"])

# Create outputs
file_output = AutoClaude::Output::File.new(log_file.path)
terminal_output = AutoClaude::Output::Terminal.new

# Multiplex to both terminal and file
multi_output = AutoClaude::Output::Multiplexer.new([terminal_output, file_output])

client = AutoClaude::Client.new(output: multi_output)
session = client.run("Say 'Hello, this message appears in both terminal and file!'")

# Close the file output
file_output.close

puts "\nLog file preview (first 200 chars):"
log_contents = File.read(log_file.path)
puts log_contents[0..200]
puts "... (#{log_contents.length} total bytes)"
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

puts "Memory capture summary:"
puts "  Total messages: #{memory_output.messages.count}"
puts "  User prompt: '#{memory_output.user_messages.first}'"
puts "  Has stats: #{memory_output.stats.any?}"
puts "  Has errors: #{memory_output.errors.any?}"
puts "  Result captured: #{session.success?}"
puts

# =============================================================================
# 6. Progress tracking with callbacks
# =============================================================================
puts "6. Progress tracking"
puts "=" * 60

client = AutoClaude::Client.new

# Track progress with different message types
progress = { text: 0, tools: 0 }

session = client.run("Create a file called test.txt with 'Hello' in it, then read it back") do |message|
  case message
  when AutoClaude::Messages::TextMessage
    progress[:text] += 1
    print "\r  Progress: #{progress[:text]} text, #{progress[:tools]} tools..."
  when AutoClaude::Messages::ToolUseMessage
    progress[:tools] += 1
    print "\r  Progress: #{progress[:text]} text, #{progress[:tools]} tools..."
  end
end

puts "\r  Completed: #{progress[:text]} text messages, #{progress[:tools]} tool uses"
puts "  Success: #{session.success?}"
puts

# =============================================================================
# 7. Working with specific directories
# =============================================================================
puts "7. Working with specific directories"
puts "=" * 60

require "tmpdir"

Dir.mktmpdir do |tmpdir|
  # Create a test file
  File.write(File.join(tmpdir, "test.txt"), "Hello from test file!")

  # Create a subdirectory too
  subdir = File.join(tmpdir, "data")
  FileUtils.mkdir_p(subdir)
  File.write(File.join(subdir, "info.json"), '{"status": "ready"}')
  
  # Run Claude in that directory
  client = AutoClaude::Client.new(directory: tmpdir)
  session = client.run("List all files recursively and show the contents of test.txt")

  puts "  Working directory: #{tmpdir}"
  puts "  Claude output: #{session.result.content[0..150]}..."
end
puts

# =============================================================================
# 8. Session resume capability
# =============================================================================
puts "8. Handling failures with resume"
puts "=" * 60

# Note: This is a conceptual example - actual resume requires a failed session
puts "  When a session fails, you can resume it:"
puts "  1. Save the session_id from a failed session"
puts "  2. Use: auto-claude --resume <session_id>"
puts "  3. Or programmatically: client.resume(session_id)"
puts
puts "  This is useful for:"
puts "  - Network interruptions"
puts "  - Rate limit errors"
puts "  - Temporary API issues"
