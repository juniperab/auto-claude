require "test_helper"
require "tmpdir"
require "fileutils"

# This test investigates Claude's actual directory access behavior
# to understand why it might be getting access to directories beyond
# what we specify
class AutoClaude::ClaudeDirectoryBehaviorTest < Minitest::Test
  def setup
    @test_real_claude = ENV["TEST_REAL_CLAUDE"]
  end

  def test_claude_directory_access_investigation
    skip "Set TEST_REAL_CLAUDE=1 to run this test" unless @test_real_claude
    
    # Get the actual parent directory of this project
    project_root = File.expand_path("../..", __dir__)
    parent_dir = File.dirname(project_root)
    
    puts "\n=== Claude Directory Access Investigation ==="
    puts "Project root: #{project_root}"
    puts "Parent directory: #{parent_dir}"
    puts "Current working directory: #{Dir.pwd}"
    
    Dir.mktmpdir do |tmpdir|
      # Create a test file in tmpdir
      File.write(File.join(tmpdir, "test_file.txt"), "This file is in the temp directory")
      
      # Create a marker file in the project root
      marker_file = File.join(project_root, "CLAUDE_TEST_MARKER.txt")
      File.write(marker_file, "This file is in the auto-claude project root")
      
      begin
        runner = AutoClaude::ClaudeRunner.new(directory: tmpdir)
        
        # Ask Claude to list what directories it can see
        result = runner.run(<<~PROMPT)
          Please tell me:
          1. What is your current working directory?
          2. List all directories you have access to (not just the current one)
          3. Can you see a file called CLAUDE_TEST_MARKER.txt anywhere? If so, where?
          4. What files can you see in /Users/juniper/src/github.com/juniperab/auto-claude/?
        PROMPT
        
        puts "\n=== Claude's Response ==="
        puts result
        puts "=== End Response ==="
        
        # Assertions to understand the behavior
        assert_match(/#{File.basename(tmpdir)}/, result, "Claude should be working in tmpdir")
        
        # Check if Claude mentions the project directory
        if result.include?("auto-claude")
          puts "\nWARNING: Claude has access to the auto-claude project directory!"
          puts "This suggests Claude is getting additional directory access beyond what we specified."
        end
        
        # Check if Claude can see the marker file
        if result.include?("CLAUDE_TEST_MARKER.txt")
          puts "\nWARNING: Claude can see the marker file in the project root!"
        end
      ensure
        File.delete(marker_file) if File.exist?(marker_file)
      end
    end
  end

  def test_claude_env_and_process_info
    skip "Set TEST_REAL_CLAUDE=1 to run this test" unless @test_real_claude
    
    Dir.mktmpdir do |tmpdir|
      runner = AutoClaude::ClaudeRunner.new(directory: tmpdir)
      
      # Ask Claude about its environment
      result = runner.run(<<~PROMPT)
        Please tell me about your environment:
        1. What environment variables do you see that might relate to directories or paths?
        2. What is the value of the PWD environment variable?
        3. Can you run the command: pwd
        4. Can you tell me what directories are listed in any CLAUDE-related environment variables?
      PROMPT
      
      puts "\n=== Claude's Environment Info ==="
      puts result
      puts "=== End Info ==="
    end
  end

  def test_claude_with_explicit_no_additional_dirs
    skip "Set TEST_REAL_CLAUDE=1 to run this test" unless @test_real_claude
    
    Dir.mktmpdir do |tmpdir|
      File.write(File.join(tmpdir, "only_file.txt"), "This should be the only file Claude can see")
      
      # Try running with explicit isolation
      runner = AutoClaude::ClaudeRunner.new(
        directory: tmpdir,
        claude_options: [] # No additional options
      )
      
      result = runner.run("List all files and directories you have access to, including parent directories")
      
      puts "\n=== Claude's Access with Explicit Isolation ==="
      puts result
      puts "=== End ==="
      
      # Check if Claude mentions any directories outside tmpdir
      project_indicators = ["auto-claude", "juniperab", "github.com"]
      project_indicators.each do |indicator|
        if result.include?(indicator)
          puts "WARNING: Claude mentioned '#{indicator}' which suggests access beyond tmpdir"
        end
      end
    end
  end

  def test_inspect_claude_process_launch
    # This test inspects how Claude is launched without actually running it
    captured_command = nil
    captured_options = nil
    
    Open3.stub :popen3, -> (*args) {
      if args.last.is_a?(Hash)
        captured_options = args.pop
        captured_command = args
      else
        captured_command = args
        captured_options = {}
      end
      
      # Don't actually run anything
      stdin = StringIO.new
      stdout = StringIO.new
      stderr = StringIO.new
      wait_thread = Object.new
      def wait_thread.value
        status = Object.new
        def status.success?; false; end
        def status.exitstatus; 1; end
        status
      end
      
      yield stdin, stdout, stderr, wait_thread if block_given?
    } do
      Dir.mktmpdir do |tmpdir|
        runner = AutoClaude::ClaudeRunner.new(directory: tmpdir)
        
        begin
          runner.run("Test")
        rescue
          # Expected to fail
        end
        
        puts "\n=== Claude Launch Investigation ==="
        puts "Command: #{captured_command.inspect}"
        puts "Options: #{captured_options.inspect}"
        puts "chdir option: #{captured_options[:chdir]}"
        
        # With wrapper script, the command is now the wrapper script path
        if captured_command.first&.include?("claude_wrapper")
          assert captured_command.first.include?("claude_wrapper"), "Should use wrapper script"
          assert captured_command.first.end_with?(".sh"), "Wrapper script should be a shell script"
          # Options should be empty when using wrapper script
          assert_empty captured_options, "Options should be empty when using wrapper script"
        else
          # Fallback behavior when wrapper is disabled
          assert_equal ["claude", "-p", "--verbose", "--output-format", "stream-json"], captured_command
          assert_equal tmpdir, captured_options[:chdir]
        end
      end
    end
  end
end