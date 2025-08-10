#!/usr/bin/env ruby

# Custom output handling with auto-claude
# Shows how to capture, redirect, and process Claude's output

require 'auto_claude'
require 'stringio'
require 'json'

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
puts "  User prompt: #{memory.user_messages.first}"
puts "  Stats: #{memory.stats.inspect}"
puts "  Info lines: #{memory.info.count}"
puts "  Errors: #{memory.errors.count}"
puts "  Result: #{session.result.content[0..50]}..."
puts

# =============================================================================
# 2. File logging
# =============================================================================
puts "2. File logging"
puts "=" * 60

require 'tempfile'

log_file = Tempfile.new(['claude', '.log'])
puts "Logging to: #{log_file.path}"

file_output = AutoClaude::Output::File.new(log_file.path)
client = AutoClaude::Client.new(output: file_output)

session = client.run("List 3 programming languages")

# Write metadata
file_output.write_metadata(session.metadata)
file_output.close

# Read and display log
log_contents = File.read(log_file.path)
puts "Log file contents (first 300 chars):"
puts log_contents[0..300]
puts "..."

log_file.unlink
puts

# =============================================================================
# 3. Multiplexed output (terminal + file)
# =============================================================================
puts "3. Multiplexed output"
puts "=" * 60

log_file = Tempfile.new(['claude_multi', '.log'])

# Create multiple outputs
terminal = AutoClaude::Output::Terminal.new
file = AutoClaude::Output::File.new(log_file.path)
memory = AutoClaude::Output::Memory.new

# Multiplex to all three
multi = AutoClaude::Output::Multiplexer.new([terminal, file, memory])

client = AutoClaude::Client.new(output: multi)
session = client.run("What is 2+2?")

file.close

puts "\nCaptured in memory: #{memory.messages.count} messages"
puts "Logged to file: #{File.size(log_file.path)} bytes"
log_file.unlink
puts

# =============================================================================
# 4. Custom output writer
# =============================================================================
puts "4. Custom output writer"
puts "=" * 60

# Create a custom output that filters messages
class FilteredOutput < AutoClaude::Output::Writer
  attr_reader :assistant_messages, :tool_uses
  
  def initialize
    @assistant_messages = []
    @tool_uses = []
  end
  
  def write_message(message)
    case message
    when AutoClaude::Messages::TextMessage
      @assistant_messages << message.text if message.role == "assistant"
    when AutoClaude::Messages::ToolUseMessage
      @tool_uses << "#{message.tool_name}: #{message.tool_input}"
    end
  end
  
  def write_stat(key, value)
    # Ignore stats
  end
  
  def write_user_message(text)
    # Ignore user messages
  end
  
  def write_error(error)
    puts "ERROR: #{error}"
  end
  
  def write_info(info)
    # Ignore info
  end
  
  def write_divider
    # Ignore dividers
  end
end

filtered = FilteredOutput.new
client = AutoClaude::Client.new(output: filtered)

session = client.run("Use the Bash tool to check the current directory")

puts "Filtered output captured:"
puts "  Assistant messages: #{filtered.assistant_messages.count}"
filtered.assistant_messages.each { |msg| puts "    - #{msg[0..50]}..." }
puts "  Tool uses: #{filtered.tool_uses.count}"
filtered.tool_uses.each { |use| puts "    - #{use}" }
puts

# =============================================================================
# 5. JSON output formatter
# =============================================================================
puts "5. JSON output formatter"
puts "=" * 60

# Custom JSON output writer
class JSONOutput < AutoClaude::Output::Writer
  attr_reader :data
  
  def initialize
    @data = {
      messages: [],
      stats: {},
      metadata: {}
    }
  end
  
  def write_message(message)
    @data[:messages] << {
      type: message.class.name.split('::').last,
      content: extract_content(message),
      timestamp: Time.now.iso8601
    }
  end
  
  def write_stat(key, value)
    @data[:stats][key] = value
  end
  
  def write_metadata(metadata)
    @data[:metadata] = metadata
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
    when AutoClaude::Messages::ToolResultMessage
      message.output
    when AutoClaude::Messages::ResultMessage
      message.content
    else
      message.to_h
    end
  end
  
  def write_user_message(text); end
  def write_error(error); end
  def write_info(info); end
  def write_divider; end
end

json_output = JSONOutput.new
client = AutoClaude::Client.new(output: json_output)

session = client.run("What is the meaning of JSON?")
json_output.write_metadata(session.metadata)

puts "JSON output:"
puts json_output.to_json[0..500] + "..."
puts

# =============================================================================
# 6. Streaming to external service
# =============================================================================
puts "6. Streaming output (simulated)"
puts "=" * 60

# Simulate streaming to an external service
class StreamingOutput < AutoClaude::Output::Writer
  def initialize(stream_url = "https://example.com/stream")
    @stream_url = stream_url
    @buffer = []
  end
  
  def write_message(message)
    # In real implementation, you'd send to the service
    @buffer << message
    puts "  [STREAM] Would send to #{@stream_url}: #{message.class.name.split('::').last}"
  end
  
  def flush
    puts "  [STREAM] Flushing #{@buffer.count} messages to service"
    @buffer.clear
  end
  
  def write_stat(key, value); end
  def write_user_message(text); end
  def write_error(error); end
  def write_info(info); end
  def write_divider; end
end

streaming = StreamingOutput.new
client = AutoClaude::Client.new(output: streaming)

session = client.run("Count to 3")
streaming.flush
puts

# =============================================================================
# 7. Silent output (no console output)
# =============================================================================
puts "7. Silent output"
puts "=" * 60

# Create a null output that discards everything
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
  session = client.run("Write a paragraph about space exploration")
  puts "Completed silently. Result length: #{session.result.content.length} chars"
end

puts "Time: #{'%.2f' % time} seconds"
puts

# =============================================================================
# 8. Output with custom formatting
# =============================================================================
puts "8. Custom formatted output"
puts "=" * 60

class PrettyOutput < AutoClaude::Output::Writer
  def write_message(message)
    case message
    when AutoClaude::Messages::TextMessage
      puts "💬 #{message.text}"
    when AutoClaude::Messages::ToolUseMessage
      puts "🔧 Using tool: #{message.tool_name}"
    when AutoClaude::Messages::ToolResultMessage
      puts "📊 Tool result received"
    when AutoClaude::Messages::ResultMessage
      puts "✅ Complete: #{message.content[0..50]}..."
    end
  end
  
  def write_stat(key, value)
    puts "📈 #{key}: #{value}"
  end
  
  def write_user_message(text)
    puts "👤 User: #{text}"
  end
  
  def write_error(error)
    puts "❌ Error: #{error}"
  end
  
  def write_info(info)
    puts "ℹ️  #{info}"
  end
  
  def write_divider
    puts "─" * 40
  end
end

pretty = PrettyOutput.new
client = AutoClaude::Client.new(output: pretty)

session = client.run("What is 10 + 10?")