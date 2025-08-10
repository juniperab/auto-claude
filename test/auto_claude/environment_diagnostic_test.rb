require "test_helper"
require "tmpdir"

class AutoClaude::EnvironmentDiagnosticTest < Minitest::Test
  def test_environment_variables_passed_to_claude
    # This test checks what environment variables are passed to the subprocess
    captured_env = nil
    
    Open3.stub :popen3, -> (*args) {
      # In popen3, if the first argument is a hash, it's the environment
      if args.first.is_a?(Hash)
        captured_env = args.shift
      end
      
      # Capture remaining args
      if args.last.is_a?(Hash)
        options = args.pop
      else
        options = {}
      end
      
      # Mock response
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
        # Save original PWD
        original_pwd = ENV['PWD']
        
        client = AutoClaude::Client.new(directory: tmpdir)
        
        begin
          client.run("Test")
        rescue
          # Expected to fail
        end
        
        puts "\n=== Environment Variables Investigation ==="
        puts "Captured environment: #{captured_env.inspect}"
        puts "Original PWD: #{original_pwd}"
        puts "Target directory: #{tmpdir}"
        
        # Check if PWD is being passed through
        if captured_env.nil?
          puts "No custom environment was set - Claude inherits all parent env vars"
          puts "This means PWD=#{ENV['PWD']} is passed to Claude"
        end
      end
    end
  end

  def test_check_claude_md_locations
    # Check for CLAUDE.md files that might be giving additional context
    project_root = File.expand_path("../..", __dir__)
    parent_dir = File.dirname(project_root)
    
    puts "\n=== CLAUDE.md File Investigation ==="
    puts "Checking for CLAUDE.md files that Claude might automatically read..."
    
    # Check current project
    claude_md_locations = []
    
    # Check project root
    if File.exist?(File.join(project_root, "CLAUDE.md"))
      claude_md_locations << File.join(project_root, "CLAUDE.md")
    end
    
    # Check parent directories
    current = project_root
    3.times do
      current = File.dirname(current)
      claude_md_path = File.join(current, "CLAUDE.md")
      if File.exist?(claude_md_path)
        claude_md_locations << claude_md_path
      end
    end
    
    # Check for .claude directory
    if Dir.exist?(File.join(project_root, ".claude"))
      puts "Found .claude directory at: #{File.join(project_root, '.claude')}"
    end
    
    # Check home directory
    home_claude = File.expand_path("~/.claude/CLAUDE.md")
    if File.exist?(home_claude)
      claude_md_locations << home_claude
    end
    
    if claude_md_locations.empty?
      puts "No CLAUDE.md files found in standard locations"
    else
      puts "Found CLAUDE.md files at:"
      claude_md_locations.each do |loc|
        puts "  - #{loc}"
        # Show first few lines
        content = File.read(loc).lines.first(3).join
        puts "    Content preview: #{content.strip.inspect}"
      end
    end
    
    # According to docs, Claude reads CLAUDE.md from:
    # - Any parent of the directory where you run claude
    # - Any child of the directory where you run claude
    puts "\nBased on documentation, when Claude runs from a directory, it reads CLAUDE.md from:"
    puts "- Any parent directory"
    puts "- Any child directory"
    puts "This might explain why it has broader access than expected"
  end

  def test_subprocess_pwd_behavior
    # Test how PWD behaves with chdir
    Dir.mktmpdir do |tmpdir|
      original_pwd = Dir.pwd
      
      # Test Ruby's Open3 behavior
      output = nil
      Open3.popen3("pwd", chdir: tmpdir) do |stdin, stdout, stderr, wait_thread|
        output = stdout.read.strip
      end
      
      puts "\n=== PWD Behavior Test ==="
      puts "Original working directory: #{original_pwd}"
      puts "Target directory: #{tmpdir}"
      puts "Output of 'pwd' command with chdir: #{output}"
      
      # Test environment
      env_output = nil
      Open3.popen3("sh", "-c", "echo PWD=$PWD", chdir: tmpdir) do |stdin, stdout, stderr, wait_thread|
        env_output = stdout.read.strip
      end
      
      puts "PWD environment variable in subprocess: #{env_output}"
      
      # The actual pwd should change (macOS might add /private prefix)
      assert output == tmpdir || output == "/private#{tmpdir}", 
        "Expected pwd to be #{tmpdir} or /private#{tmpdir}, but got #{output}"
      
      # But PWD env var might not be updated automatically
      if env_output.include?(original_pwd)
        puts "WARNING: PWD environment variable was not updated by chdir!"
        puts "This means Claude might see PWD=#{original_pwd} even when running in #{tmpdir}"
      end
    end
  end
end