#!/usr/bin/env ruby
# frozen_string_literal: true

# Custom output handling with auto-claude
# Shows how to capture, redirect, and customize Claude's output

require "auto_claude"
require "stringio"
require "json"

# =============================================================================
# 1. Memory output for testing
# =============================================================================
puts "1. Memory output (capture everything)"
puts "=" * 60

memory = AutoClaude::Output::Memory.new
client = AutoClaude::Client.new(output: memory)

session = client.run("What is Ruby?")

puts "Captured data:"
puts "  Messages: #{memory.messages.count}"
puts "  First user message: '#{memory.user_messages.first}'"
puts "  Stats collected: #{memory.stats.any?}"
puts "  Info messages: #{memory.info.count}"
puts "  Error count: #{memory.errors.count}"
puts "  Result: #{session.result.content[0..50]}..."
puts

# =============================================================================
# 2. File logging
# =============================================================================
puts "2. File logging"
puts "=" * 60

require "tempfile"

log_file = Tempfile.new(["claude", ".log"])
puts "Logging to: #{log_file.path}"

file_output = AutoClaude::Output::File.new(log_file.path)
client = AutoClaude::Client.new(output: file_output)

session = client.run("List 3 programming languages")

# Close the file
file_output.close

# Read and display log
log_contents = File.read(log_file.path)
puts "Log preview (#{log_contents.lines.count} lines, #{log_contents.length} bytes):"
puts log_contents.lines.first(5).join
puts "..."

log_file.unlink
puts

# =============================================================================
# 3. Multiplexed output (terminal + file)
# =============================================================================
puts "3. Multiplexed output"
puts "=" * 60

log_file = Tempfile.new(["claude_multi", ".log"])

# Create multiple outputs
terminal = AutoClaude::Output::Terminal.new
file = AutoClaude::Output::File.new(log_file.path)
memory = AutoClaude::Output::Memory.new

# Multiplex to all three
multi = AutoClaude::Output::Multiplexer.new([terminal, file, memory])

client = AutoClaude::Client.new(output: multi)
session = client.run("What is 2+2?")

file.close

puts "\nResults:"
puts "  Answer: #{session.result.content}"
puts "  Captured in memory: #{memory.messages.count} messages"
puts "  Logged to file: #{File.size(log_file.path)} bytes"
log_file.unlink
puts

# =============================================================================
# 4. Custom output writer
# =============================================================================
puts "4. Custom output writer"
puts "=" * 60

# Create a custom output that only captures certain messages
class FilteredOutput < AutoClaude::Output::Writer
  attr_reader :text_messages, :tool_uses

  def initialize
    @text_messages = []
    @tool_uses = []
  end

  def write_message(message)
    case message
    when AutoClaude::Messages::TextMessage
      @text_messages << message.text
    when AutoClaude::Messages::ToolUseMessage
      @tool_uses << { tool: message.tool_name, input: message.tool_input }
    end
  end

  def write_stat(key, value); end
  def write_user_message(text); end
  def write_error(error)
    puts "[ERROR] #{error}"
  end
  def write_info(info); end
  def write_divider; end
end

filtered = FilteredOutput.new
client = AutoClaude::Client.new(output: filtered)

session = client.run("What is 5 + 5? Then use the Bash tool to run 'echo Hello'")

puts "Filtered capture:"
puts "  Text messages: #{filtered.text_messages.count}"
filtered.text_messages.each { |msg| puts "    - #{msg[0..60]}..." if msg.length > 60 }
puts "  Tools used: #{filtered.tool_uses.count}"
filtered.tool_uses.each { |use| puts "    - #{use[:tool]}: #{use[:input][0..50]}..." }
puts

# =============================================================================
# 5. JSON output formatter
# =============================================================================
puts "5. JSON output formatter"
puts "=" * 60

# JSON output formatter for structured logging
class JSONOutput < AutoClaude::Output::Writer
  attr_reader :data

  def initialize
    @data = {
      messages: [],
      stats: {},
      errors: []
    }
  end

  def write_message(message)
    @data[:messages] << {
      type: message.class.name.split("::").last,
      content: extract_content(message),
      timestamp: Time.now.iso8601
    }
  end

  def write_stat(key, value)
    @data[:stats][key] = value
  end

  def write_error(error)
    @data[:errors] << error
  end

  def to_json
    JSON.pretty_generate(@data)
  end

  private

  def extract_content(message)
    case message
    when AutoClaude::Messages::TextMessage
      message.text
    when AutoClaude::Messages::ToolUseMessage
      { tool: message.tool_name, input: message.tool_input }
    when AutoClaude::Messages::ResultMessage
      message.content
    else
      message.to_s
    end
  end

  def write_user_message(text); end
  def write_info(info); end
  def write_divider; end
end

json_output = JSONOutput.new
client = AutoClaude::Client.new(output: json_output)

session = client.run("What is JSON?")

json_str = json_output.to_json
puts "JSON output (#{json_str.lines.count} lines):"
puts json_str.lines.first(10).join
puts "..."
puts

# =============================================================================
# 6. Streaming to external service
# =============================================================================
puts "6. Streaming output (simulated)"
puts "=" * 60

# Simulate streaming to a webhook or service
class WebhookOutput < AutoClaude::Output::Writer
  def initialize(webhook_url = "https://example.com/webhook")
    @webhook_url = webhook_url
    @events = []
  end

  def write_message(message)
    event = { type: message.class.name.split("::").last, timestamp: Time.now.to_f }
    @events << event
    puts "  [WEBHOOK] Sending event to #{@webhook_url}: #{event[:type]}"
  end

  def flush
    puts "  [WEBHOOK] Batch sending #{@events.count} events"
    @events.clear
  end

  def write_stat(key, value); end
  def write_user_message(text); end
  def write_error(error); end
  def write_info(info); end
  def write_divider; end
end

webhook = WebhookOutput.new
client = AutoClaude::Client.new(output: webhook)

session = client.run("Count to 3")
webhook.flush
puts

# =============================================================================
# 7. Silent output (no console output)
# =============================================================================
puts "7. Silent output"
puts "=" * 60

# Null output - discards everything for silent operation
class NullOutput < AutoClaude::Output::Writer
  def write_message(message); end
  def write_stat(key, value); end
  def write_user_message(text); end
  def write_error(error); end
  def write_info(info); end
  def write_divider; end
end

puts "Running silently (no output to console)..."
null_output = NullOutput.new
client = AutoClaude::Client.new(output: null_output)

time = Benchmark.realtime do
  session = client.run("Explain recursion in one sentence")
  puts "Completed silently in #{"%.2f" % time}s"
  puts "Result: #{session.result.content[0..80]}..."
end
puts

# =============================================================================
# 8. Output with custom formatting
# =============================================================================
puts "8. Custom formatted output"
puts "=" * 60

# Custom formatter with emojis and colors
class PrettyOutput < AutoClaude::Output::Writer
  def write_message(message)
    case message
    when AutoClaude::Messages::TextMessage
      puts "  💬 #{message.text[0..100]}#{'...' if message.text.length > 100}"
    when AutoClaude::Messages::ToolUseMessage
      puts "  🔧 Tool: #{message.tool_name}"
    when AutoClaude::Messages::ToolResultMessage
      puts "  ✔️  Tool completed"
    when AutoClaude::Messages::ResultMessage
      status = message.success? ? "✅ Success" : "❌ Failed"
      puts "  #{status}"
    end
  end

  def write_stat(key, value)
    puts "  📊 #{key}: #{value}"
  end

  def write_user_message(text)
    puts "  👤 User: #{text}"
  end

  def write_error(error)
    puts "  ⚠️  Error: #{error}"
  end

  def write_info(info)
    puts "  ℹ️  #{info}"
  end

  def write_divider
    puts "  #{'-' * 40}"
  end
end

pretty = PrettyOutput.new
client = AutoClaude::Client.new(output: pretty)

session = client.run("What is 10 + 10?")
puts "\nFinal answer: #{session.result.content}"
puts
