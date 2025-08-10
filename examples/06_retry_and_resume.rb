#!/usr/bin/env ruby

# Retry and resume functionality with auto-claude
# Shows how to handle failures and continue sessions

require 'auto_claude'

# =============================================================================
# 1. Basic retry with App.run
# =============================================================================
puts "1. Basic retry with App.run"
puts "=" * 60

# With retry_on_error: true, auto-claude will:
# - Try up to 3 times total (1 initial + 2 retries)
# - Automatically use --resume with the session ID from failed attempts
result = AutoClaude::App.run(
  "What is the capital of France?",
  retry_on_error: true
)

puts "Result (with automatic retry if needed): #{result}"
puts

# =============================================================================
# 2. Manual retry with session resumption
# =============================================================================
puts "2. Manual retry with session resumption"
puts "=" * 60

client = AutoClaude::Client.new
session = nil
max_attempts = 3

max_attempts.times do |attempt|
  puts "  Attempt #{attempt + 1}/#{max_attempts}"
  
  # On retry, use the session ID from the previous attempt
  if session&.session_id
    puts "  Resuming session: #{session.session_id}"
    client = AutoClaude::Client.new(
      claude_options: ["--resume", session.session_id]
    )
  end
  
  session = client.run("Calculate 123 * 456")
  
  if session.success?
    puts "  Success! Result: #{session.result.content}"
    break
  else
    puts "  Failed: #{session.result.error_message}"
    puts "  Session ID for resume: #{session.session_id}" if session.session_id
  end
end
puts

# =============================================================================
# 3. Continuing a specific session
# =============================================================================
puts "3. Continuing a specific session"
puts "=" * 60

# First session
client1 = AutoClaude::Client.new
session1 = client1.run("Start counting from 1")

puts "First session:"
puts "  Result: #{session1.result.content}"
puts "  Session ID: #{session1.session_id}"

if session1.session_id
  # Continue the same session
  puts "\nContinuing session #{session1.session_id}..."
  
  client2 = AutoClaude::Client.new(
    claude_options: ["--resume", session1.session_id]
  )
  
  session2 = client2.run("Continue counting for 3 more numbers")
  puts "  Continued result: #{session2.result.content}"
  puts "  Same conversation: #{session2.session_id == session1.session_id}"
end
puts

# =============================================================================
# 4. Retry with exponential backoff
# =============================================================================
puts "4. Retry with exponential backoff"
puts "=" * 60

def with_exponential_backoff(max_attempts: 3, base_delay: 1)
  attempt = 0
  session = nil
  
  while attempt < max_attempts
    attempt += 1
    delay = base_delay * (2 ** (attempt - 1))  # 1s, 2s, 4s, etc.
    
    puts "  Attempt #{attempt}/#{max_attempts}"
    
    # Create client with resume if we have a session ID
    options = []
    if session&.session_id
      options = ["--resume", session.session_id]
      puts "  Resuming from: #{session.session_id}"
    end
    
    client = AutoClaude::Client.new(claude_options: options)
    session = client.run(yield)
    
    if session.success?
      puts "  Success!"
      return session
    else
      puts "  Failed: #{session.result.error_message}"
      
      if attempt < max_attempts
        puts "  Waiting #{delay} seconds before retry..."
        sleep delay
      end
    end
  end
  
  puts "  All attempts exhausted"
  session
end

session = with_exponential_backoff(max_attempts: 3, base_delay: 0.5) do
  "What is the square root of 144?"
end

puts "Final result: #{session.result.content if session.success?}"
puts

# =============================================================================
# 5. Retry with different strategies
# =============================================================================
puts "5. Retry with different strategies"
puts "=" * 60

class RetryStrategy
  def self.with_resume(prompt, max_attempts: 3)
    session = nil
    client = nil
    
    max_attempts.times do |attempt|
      # Use resume on retry
      if session&.session_id && attempt > 0
        client = AutoClaude::Client.new(
          claude_options: ["--resume", session.session_id]
        )
      else
        client = AutoClaude::Client.new
      end
      
      session = client.run(prompt)
      return session if session.success?
    end
    
    session
  end
  
  def self.fresh_start(prompt, max_attempts: 3)
    session = nil
    
    max_attempts.times do |attempt|
      # Always start fresh, no resume
      client = AutoClaude::Client.new
      session = client.run(prompt)
      return session if session.success?
    end
    
    session
  end
  
  def self.with_fallback_model(prompt, models: ["claude-3-5-sonnet-20241022", "claude-3-opus-20240229"])
    models.each_with_index do |model, i|
      puts "  Trying with model: #{model}"
      
      client = AutoClaude::Client.new(
        claude_options: ["--model", model]
      )
      
      session = client.run(prompt)
      
      if session.success?
        puts "  Success with #{model}"
        return session
      else
        puts "  Failed with #{model}"
      end
    end
    
    nil
  end
end

# Try different strategies
puts "Strategy 1: With resume"
session = RetryStrategy.with_resume("What is 2+2?", max_attempts: 2)
puts "  Result: #{session.result.content if session&.success?}"

puts "\nStrategy 2: Fresh start each time"
session = RetryStrategy.fresh_start("What is 3+3?", max_attempts: 2)
puts "  Result: #{session.result.content if session&.success?}"

puts "\nStrategy 3: Fallback models"
session = RetryStrategy.with_fallback_model("What is 4+4?")
puts "  Result: #{session.result.content if session&.success?}"
puts

# =============================================================================
# 6. Handling partial failures
# =============================================================================
puts "6. Handling partial failures"
puts "=" * 60

# Process multiple items with retry for failures
items = ["Task 1", "Task 2", "Task 3"]
results = []

items.each do |item|
  puts "Processing: #{item}"
  
  # Try with retry
  success = false
  session = nil
  
  2.times do |attempt|
    options = []
    if session&.session_id && attempt > 0
      options = ["--resume", session.session_id]
      puts "  Retrying with resume..."
    end
    
    client = AutoClaude::Client.new(claude_options: options)
    session = client.run("Process this: #{item}")
    
    if session.success?
      results << { item: item, result: session.result.content, attempts: attempt + 1 }
      success = true
      break
    end
  end
  
  unless success
    results << { item: item, error: session&.result&.error_message || "Unknown error" }
  end
end

puts "\nResults:"
results.each do |r|
  if r[:error]
    puts "  #{r[:item]}: ERROR - #{r[:error]}"
  else
    puts "  #{r[:item]}: #{r[:result]} (#{r[:attempts]} attempts)"
  end
end
puts

# =============================================================================
# 7. Session chaining with retry
# =============================================================================
puts "7. Session chaining with retry"
puts "=" * 60

def run_with_retry(prompt, session_id = nil)
  max_attempts = 2
  
  max_attempts.times do |attempt|
    options = session_id ? ["--resume", session_id] : []
    client = AutoClaude::Client.new(claude_options: options)
    
    session = client.run(prompt)
    
    if session.success?
      return session
    elsif attempt < max_attempts - 1
      puts "  Retrying after failure..."
      session_id = session.session_id if session.session_id
    end
  end
  
  nil
end

# Chain multiple operations with retry
puts "Running chained operations with retry support:"

# Step 1
session1 = run_with_retry("Step 1: Start a calculation with 100")
if session1&.success?
  puts "  Step 1 complete: #{session1.result.content}"
  
  # Step 2 - continue from step 1
  session2 = run_with_retry("Step 2: Multiply the previous number by 2", session1.session_id)
  if session2&.success?
    puts "  Step 2 complete: #{session2.result.content}"
    
    # Step 3 - continue from step 2
    session3 = run_with_retry("Step 3: Add 50 to the result", session2.session_id)
    if session3&.success?
      puts "  Step 3 complete: #{session3.result.content}"
    end
  end
end