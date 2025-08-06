require "test_helper"
require "tmpdir"

class AutoClaude::DirectoryIsolationTest < Minitest::Test
  def setup
    @test_real_claude = ENV["TEST_REAL_CLAUDE"]
  end

  def test_claude_runner_sets_working_directory_via_popen3
    skip "Set TEST_REAL_CLAUDE=1 to run this test" unless @test_real_claude
    
    Dir.mktmpdir do |tmpdir|
      # Create a test file in the tmpdir
      test_file = File.join(tmpdir, "test_file.txt")
      File.write(test_file, "This is a test file in the temporary directory")
      
      # Create another file outside the tmpdir that claude shouldn't access
      outside_file = File.join(Dir.tmpdir, "outside_#{Time.now.to_i}.txt")
      File.write(outside_file, "This file is outside the working directory")
      
      begin
        runner = AutoClaude::ClaudeRunner.new(directory: tmpdir)
        result = runner.run("List all files in the current directory and tell me their names")
        
        # Claude should see the test file
        assert_match(/test_file\.txt/, result)
        
        # Claude should be working in the tmpdir
        assert_match(/#{File.basename(tmpdir)}/, result)
      ensure
        File.delete(outside_file) if File.exist?(outside_file)
      end
    end
  end

  def test_claude_runner_uses_current_directory_when_none_specified
    skip "Set TEST_REAL_CLAUDE=1 to run this test" unless @test_real_claude
    
    # Save current directory
    original_dir = Dir.pwd
    
    Dir.mktmpdir do |tmpdir|
      begin
        Dir.chdir(tmpdir) do
          # Create a marker file
          File.write("marker.txt", "Current directory marker")
          
          runner = AutoClaude::ClaudeRunner.new
          result = runner.run("What is the current working directory path?")
          
          # Should be working in the tmpdir
          assert_match(/#{File.basename(tmpdir)}/, result)
        end
      ensure
        Dir.chdir(original_dir) if Dir.pwd != original_dir
      end
    end
  end

  def test_app_run_sets_working_directory
    skip "Set TEST_REAL_CLAUDE=1 to run this test" unless @test_real_claude
    
    Dir.mktmpdir do |tmpdir|
      # Create test files
      File.write(File.join(tmpdir, "app_test.txt"), "Testing App.run")
      
      result = AutoClaude::App.run(
        "List files in the current directory", 
        directory: tmpdir
      )
      
      assert_match(/app_test\.txt/, result)
    end
  end

  def test_error_when_directory_does_not_exist
    non_existent_dir = "/tmp/definitely_does_not_exist_#{Time.now.to_i}"
    
    assert_raises(RuntimeError) do
      runner = AutoClaude::ClaudeRunner.new(directory: non_existent_dir)
      runner.run("Test")
    end
  end

  def test_wrapper_script_is_used
    # This test verifies that the wrapper script is always used
    wrapper_path_used = nil
    
    Open3.stub :popen3, -> (*args) {
      # Capture the command being executed
      wrapper_path_used = args.first if args.first && args.first.include?('claude_wrapper')
      
      # Minimal mock to not crash
      stdin = StringIO.new
      stdout = StringIO.new('{"type":"result","subtype":"success","result":"test"}' + "\n")
      stderr = StringIO.new
      wait_thread = Object.new
      def wait_thread.value
        status = Object.new
        def status.success?; true; end
        def status.exitstatus; 0; end
        status
      end
      
      yield stdin, stdout, stderr, wait_thread if block_given?
    } do
      Dir.mktmpdir do |tmpdir|
        runner = AutoClaude::ClaudeRunner.new(directory: tmpdir)
        runner.run("Test")
        
        # Verify that a wrapper script was used
        refute_nil wrapper_path_used, "Should use wrapper script"
        assert wrapper_path_used.include?("claude_wrapper"), "Should use claude_wrapper script"
        assert wrapper_path_used.end_with?(".sh"), "Wrapper should be a shell script"
      end
    end
  end
end