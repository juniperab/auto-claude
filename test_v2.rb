#!/usr/bin/env ruby

# Test script for V2 implementation
require_relative 'lib/auto_claude/v2'

puts "Testing AutoClaude V2 Implementation"
puts "=" * 40

# Test 1: Basic client usage
puts "\n1. Testing basic client usage:"
client = AutoClaude::V2::Client.new
puts "   ✓ Client created"

# Test 2: Memory output
puts "\n2. Testing with memory output:"
memory_output = AutoClaude::V2::Output::Memory.new
client_with_memory = AutoClaude::V2::Client.new(output: memory_output)
puts "   ✓ Client with memory output created"

# Test 3: Message parsing
puts "\n3. Testing message parsing:"
test_json = {
  "type" => "assistant",
  "message" => {
    "content" => [
      {"type" => "text", "text" => "Test message"}
    ]
  }
}
message = AutoClaude::V2::Messages::Base.from_json(test_json)
puts "   ✓ Text message parsed: #{message.text}"

# Test 4: Formatter
puts "\n4. Testing formatter:"
formatter = AutoClaude::V2::Output::Formatter.new
formatted = formatter.format_message(message)
puts "   ✓ Message formatted: #{formatted.strip}"

# Test 5: CLI argument parsing (non-interactive)
puts "\n5. Testing CLI argument parsing:"
begin
  # This will fail because no prompt provided, but that's expected
  AutoClaude::V2::CLI.send(:parse_arguments, ["--help"])
  puts "   ✓ Help parsing works"
rescue => e
  puts "   ✗ Error: #{e.message}"
end

begin
  args = AutoClaude::V2::CLI.send(:parse_arguments, ["-d", "/tmp", "test prompt"])
  puts "   ✓ Arguments parsed: directory=#{args[:directory]}, prompt=#{args[:prompt]}"
rescue => e
  puts "   ✗ Error: #{e.message}"
end

# Test 6: Process wrapper
puts "\n6. Testing process wrapper:"
wrapper = AutoClaude::V2::Process::Wrapper.new(Dir.pwd)
script_path = wrapper.create_script(["echo", "hello"])
if File.exist?(script_path)
  puts "   ✓ Wrapper script created at #{script_path}"
  wrapper.cleanup
  puts "   ✓ Wrapper script cleaned up"
else
  puts "   ✗ Failed to create wrapper script"
end

# Test 7: V2 module convenience method (mock)
puts "\n7. Testing V2 convenience method:"
begin
  # This would normally call Claude, so we'll just test it exists
  puts "   ✓ AutoClaude::V2.run method exists" if AutoClaude::V2.respond_to?(:run)
rescue => e
  puts "   ✗ Error: #{e.message}"
end

puts "\n" + "=" * 40
puts "V2 Implementation Test Complete!"
puts "\nTo test with real Claude, run:"
puts "  ruby -Ilib -rauto_claude/v2 -e 'client = AutoClaude::V2::Client.new; session = client.run(\"What is 2+2?\"); puts session.result.content'"