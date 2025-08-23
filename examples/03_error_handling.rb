#!/usr/bin/env ruby
# frozen_string_literal: true

# Error handling and retry strategies with auto-claude
# Shows how to handle failures gracefully

require "auto_claude"

# =============================================================================
# 1. Basic error detection
# =============================================================================
puts "1. Basic error detection"
puts "=" * 60

client = AutoClaude::Client.new(output: AutoClaude::Output::Memory.new)

# Simulate a prompt that might fail
session = client.run("This is a test prompt")

if session.success?
  puts "Success! Result: #{session.result.content}"
else
  puts "Failed! Error: #{session.result.error_message}"
  puts "Session still has ID: #{session.session_id}" if session.session_id
end
puts

# =============================================================================
# 2. Handling exceptions
# =============================================================================
puts "2. Handling exceptions"
puts "=" * 60

begin
  # This will raise an error because --verbose is managed by auto-claude
  client = AutoClaude::Client.new(
    claude_options: ["--verbose"]
  )
rescue ArgumentError => e
  puts "Caught expected error: #{e.message}"
end

begin
  # Invalid directory
  client = AutoClaude::Client.new(
    directory: "/nonexistent/directory"
  )
rescue ArgumentError => e
  puts "Caught directory error: #{e.message}"
end
puts

# =============================================================================
# 3. Retry on failure with App.run
# =============================================================================
puts "3. Automatic retry with App.run"
puts "=" * 60

# NOTE: In real usage, this would retry if the first attempt fails
result = AutoClaude::App.run(
  "What is 2+2?",
  retry_on_error: true # Will retry up to 2 times (3 total attempts)
)

puts "Result after potential retries: #{result}"
puts

# =============================================================================
# 4. Manual retry logic with Client
# =============================================================================
puts "4. Manual retry logic"
puts "=" * 60

client = AutoClaude::Client.new
max_attempts = 3
attempt = 0
session = nil

while attempt < max_attempts
  attempt += 1
  puts "  Attempt #{attempt}/#{max_attempts}..."

  # On retry, use session ID from previous attempt if available
  options = []
  if session&.session_id
    options = ["--resume", session.session_id]
    puts "  Resuming from session: #{session.session_id}"
  end

  # Create new client with resume option if retrying
  client = AutoClaude::Client.new(claude_options: options) if attempt > 1

  session = client.run("Calculate 10 * 5")

  if session.success?
    puts "  Success on attempt #{attempt}!"
    puts "  Result: #{session.result.content}"
    break
  else
    puts "  Failed on attempt #{attempt}: #{session.result.error_message}"

    if attempt < max_attempts
      puts "  Will retry..."
      sleep 1 # Brief delay before retry
    else
      puts "  All attempts exhausted."
    end
  end
end
puts

# =============================================================================
# 5. Timeout handling
# =============================================================================
puts "5. Timeout handling (demonstration)"
puts "=" * 60

require "timeout"

client = AutoClaude::Client.new

begin
  # Set a timeout for the operation
  Timeout.timeout(30) do # 30 second timeout
    session = client.run("What is the meaning of life?")
    puts "Completed within timeout: #{session.result.content}"
  end
rescue Timeout::Error
  puts "Operation timed out after 30 seconds"
end
puts

# =============================================================================
# 6. Error recovery with fallback
# =============================================================================
puts "6. Error recovery with fallback"
puts "=" * 60

def safe_claude_query(prompt, fallback_response = "Unable to process request")
  client = AutoClaude::Client.new
  session = client.run(prompt)

  if session.success?
    session.result.content
  else
    puts "  Claude error: #{session.result.error_message}"
    fallback_response
  end
rescue StandardError => e
  puts "  Exception: #{e.message}"
  fallback_response
end

result = safe_claude_query(
  "What is 2+2?",
  "4 (fallback answer)"
)
puts "Result: #{result}"
puts

# =============================================================================
# 7. Collecting errors across multiple operations
# =============================================================================
puts "7. Batch operations with error collection"
puts "=" * 60

questions = [
  "What is 1+1?",
  "What is 2+2?",
  "What is 3+3?"
]

results = []
errors = []

client = AutoClaude::Client.new

questions.each_with_index do |question, i|
  puts "  Processing question #{i + 1}/#{questions.length}..."

  begin
    session = client.run(question)

    if session.success?
      results << {
        question: question,
        answer: session.result.content,
        session_id: session.session_id
      }
    else
      errors << {
        question: question,
        error: session.result.error_message,
        session_id: session.session_id
      }
    end
  rescue StandardError => e
    errors << {
      question: question,
      error: e.message,
      exception: true
    }
  end
end

puts "\nSuccessful: #{results.count}/#{questions.length}"
results.each do |r|
  puts "  Q: #{r[:question]}"
  puts "  A: #{r[:answer]}"
end

if errors.any?
  puts "\nErrors: #{errors.count}"
  errors.each do |e|
    puts "  Q: #{e[:question]}"
    puts "  Error: #{e[:error]}"
  end
end
puts

# =============================================================================
# 8. Using session information for debugging
# =============================================================================
puts "8. Debugging with session information"
puts "=" * 60

memory_output = AutoClaude::Output::Memory.new
client = AutoClaude::Client.new(output: memory_output)

session = client.run("What is the capital of France?")

puts "Debug Information:"
puts "  Success: #{session.success?}"
puts "  Session ID: #{session.session_id}"
puts "  Messages exchanged: #{session.messages.count}"
puts "  Duration: #{"%.3f" % session.duration}s"
puts "  Cost: $#{"%.6f" % session.cost}"

unless session.success?
  puts "\nError details:"
  puts "  Error message: #{session.result.error_message}"
  puts "  Captured errors: #{memory_output.errors.inspect}"
  puts "  Last info: #{memory_output.info.last}"
end
