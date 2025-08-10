#!/usr/bin/env ruby

# Concurrent and parallel execution with auto-claude
# Shows how to run multiple Claude sessions efficiently

require 'auto_claude'
require 'benchmark'

# =============================================================================
# 1. Simple concurrent execution
# =============================================================================
puts "1. Simple concurrent execution"
puts "=" * 60

client = AutoClaude::Client.new

# Start 3 sessions concurrently
threads = [
  client.run_async("What is the capital of France?"),
  client.run_async("What is the capital of Japan?"),
  client.run_async("What is the capital of Brazil?")
]

# Wait for all to complete
sessions = threads.map(&:value)

sessions.each_with_index do |session, i|
  puts "  Session #{i+1}: #{session.result.content}"
end
puts

# =============================================================================
# 2. Parallel processing of a list
# =============================================================================
puts "2. Parallel processing of a list"
puts "=" * 60

# List of items to process
math_problems = [
  "What is 15 + 27?",
  "What is 100 - 43?",
  "What is 12 * 8?",
  "What is 144 / 12?",
  "What is 2^10?"
]

client = AutoClaude::Client.new

# Process all in parallel
time = Benchmark.realtime do
  threads = math_problems.map do |problem|
    client.run_async(problem)
  end
  
  # Collect results as they complete
  threads.each_with_index do |thread, i|
    session = thread.value
    puts "  #{math_problems[i]} = #{session.result.content}"
  end
end

puts "Processed #{math_problems.length} problems in #{'%.2f' % time} seconds"
puts

# =============================================================================
# 3. Thread pool pattern
# =============================================================================
puts "3. Thread pool pattern (batched processing)"
puts "=" * 60

# Many tasks to process
tasks = (1..10).map { |i| "What is #{i} squared?" }

# Process in batches of 3 to avoid overwhelming the system
batch_size = 3
results = []

tasks.each_slice(batch_size).with_index do |batch, batch_num|
  puts "  Processing batch #{batch_num + 1}..."
  
  client = AutoClaude::Client.new
  
  # Process this batch in parallel
  threads = batch.map { |task| client.run_async(task) }
  batch_results = threads.map(&:value)
  
  batch_results.each_with_index do |session, i|
    task_index = batch_num * batch_size + i
    results << "#{tasks[task_index]} = #{session.result.content}"
  end
end

puts "\nAll results:"
results.each { |r| puts "  #{r}" }
puts

# =============================================================================
# 4. Producer-consumer pattern
# =============================================================================
puts "4. Producer-consumer pattern"
puts "=" * 60

require 'thread'

# Create a queue for tasks
task_queue = Queue.new
result_queue = Queue.new

# Add tasks to queue
5.times do |i|
  task_queue << "What is #{i * 10}% of 200?"
end

# Create worker threads
workers = 2.times.map do |worker_id|
  Thread.new do
    client = AutoClaude::Client.new
    
    while !task_queue.empty?
      begin
        task = task_queue.pop(true)  # Non-blocking pop
        puts "  Worker #{worker_id}: Processing '#{task}'"
        
        session = client.run(task)
        result_queue << {
          task: task,
          result: session.result.content,
          worker: worker_id
        }
      rescue ThreadError
        # Queue is empty
        break
      end
    end
  end
end

# Wait for workers to complete
workers.each(&:join)

# Collect results
puts "\nResults:"
until result_queue.empty?
  item = result_queue.pop
  puts "  #{item[:task]} = #{item[:result]} (worker #{item[:worker]})"
end
puts

# =============================================================================
# 5. Async with callbacks for real-time updates
# =============================================================================
puts "5. Async with real-time callbacks"
puts "=" * 60

client = AutoClaude::Client.new

# Track completion
completed = 0
total = 3

# Start multiple async sessions with callbacks
threads = [
  ["What color is the sky?", "Sky"],
  ["What color is grass?", "Grass"],
  ["What color is snow?", "Snow"]
].map do |question, label|
  Thread.new do
    session = client.run(question) do |message|
      if message.is_a?(AutoClaude::Messages::ResultMessage)
        completed += 1
        puts "  [#{completed}/#{total}] #{label} question completed"
      end
    end
    [label, session]
  end
end

# Wait and collect results
results = threads.map(&:value)

puts "\nFinal answers:"
results.each do |label, session|
  puts "  #{label}: #{session.result.content}"
end
puts

# =============================================================================
# 6. Concurrent different types of tasks
# =============================================================================
puts "6. Mixed task types concurrently"
puts "=" * 60

client = AutoClaude::Client.new

# Different types of tasks
tasks = {
  math: "Solve: 2x + 5 = 13",
  creative: "Write a haiku about coding",
  factual: "What year was Ruby created?",
  analytical: "List pros and cons of async programming"
}

# Run all concurrently
time = Benchmark.realtime do
  threads = tasks.map do |type, prompt|
    Thread.new do
      session = client.run(prompt)
      [type, session]
    end
  end
  
  # Collect and display results
  results = threads.map(&:value)
  
  results.each do |type, session|
    puts "  [#{type}]: #{session.result.content[0..100]}#{'...' if session.result.content.length > 100}"
  end
end

puts "\nCompleted #{tasks.size} diverse tasks in #{'%.2f' % time} seconds"
puts

# =============================================================================
# 7. Error handling in concurrent execution
# =============================================================================
puts "7. Concurrent execution with error handling"
puts "=" * 60

client = AutoClaude::Client.new

questions = [
  "What is 1+1?",
  "What is 2+2?",
  "What is 3+3?"
]

successful = []
failed = []

threads = questions.map do |question|
  Thread.new do
    begin
      session = client.run(question)
      
      if session.success?
        successful << { question: question, answer: session.result.content }
      else
        failed << { question: question, error: session.result.error_message }
      end
      
      session
    rescue => e
      failed << { question: question, error: e.message }
      nil
    end
  end
end

# Wait for all threads
threads.each(&:join)

puts "Successful: #{successful.count}"
successful.each { |s| puts "  #{s[:question]} = #{s[:answer]}" }

if failed.any?
  puts "\nFailed: #{failed.count}"
  failed.each { |f| puts "  #{f[:question]}: #{f[:error]}" }
end