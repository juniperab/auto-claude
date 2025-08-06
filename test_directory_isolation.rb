#!/usr/bin/env ruby

# Demo script to show directory isolation
require_relative 'lib/auto_claude'
require 'tmpdir'

puts "Testing directory isolation in auto-claude"
puts "=" * 50

# Create two temporary directories
Dir.mktmpdir("test_workspace") do |workspace|
  Dir.mktmpdir("test_other") do |other_dir|
    # Put files in both directories
    File.write(File.join(workspace, "allowed_file.txt"), "This file should be accessible")
    File.write(File.join(other_dir, "forbidden_file.txt"), "This file should NOT be accessible")
    
    puts "\nCreated test directories:"
    puts "  Workspace: #{workspace}"
    puts "  Other dir: #{other_dir}"
    puts "\nFiles created:"
    puts "  #{workspace}/allowed_file.txt"
    puts "  #{other_dir}/forbidden_file.txt"
    
    puts "\nRunning auto-claude with working directory set to workspace..."
    puts "-" * 50
    
    result = AutoClaude::App.run(
      "Please tell me: 1) What is the current working directory? 2) List all .txt files you can find in the current directory",
      directory: workspace
    )
    
    puts "\nResult:"
    puts result
    
    puts "\n" + "=" * 50
    puts "Analysis:"
    if result.include?("allowed_file.txt")
      puts "✓ Claude correctly found allowed_file.txt in the workspace"
    else
      puts "✗ Claude did not find allowed_file.txt"
    end
    
    if result.include?("forbidden_file.txt")
      puts "✗ Claude incorrectly found forbidden_file.txt from outside the workspace!"
    else
      puts "✓ Claude correctly did not find forbidden_file.txt from outside"
    end
  end
end