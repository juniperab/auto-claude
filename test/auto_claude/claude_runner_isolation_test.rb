require_relative '../test_helper'
require 'tmpdir'

class ClaudeRunnerIsolationTest < Minitest::Test
  
  def test_wrapper_script_prevents_parent_directory_leak
    skip "Skipping real Claude test" unless ENV['TEST_REAL_CLAUDE'] == '1'
    
    Dir.mktmpdir do |tmpdir|
      # Wrapper script is now always used
      
      runner = AutoClaude::ClaudeRunner.new(directory: tmpdir)
      result = runner.run("What directories do you have access to? Do you see any reference to 'auto-claude' directory?")
      
      # Claude should not see the auto-claude project directory
      refute_includes result, "/Users/juniper/src/github.com/juniperab/auto-claude",
        "Claude should not see the auto-claude project directory when using wrapper script"
      
      # Claude should be able to work in the specified directory
      assert_includes result, tmpdir.sub("/private", ""),
        "Claude should see the specified working directory"
    end
  end
  
  
  def test_wrapper_script_cleans_up_after_itself
    Dir.mktmpdir do |tmpdir|
      runner = AutoClaude::ClaudeRunner.new(directory: tmpdir)
      
      # Count temp files before
      temp_files_before = Dir.glob("/tmp/claude_wrapper*.sh").count
      
      # Mock claude command to avoid actual execution
      mock_response = {
        "type" => "result",
        "subtype" => "success", 
        "result" => "test response",
        "success" => true,
        "num_turns" => 1,
        "duration_ms" => 100,
        "total_cost_usd" => 0.01,
        "usage" => {"input_tokens" => 10, "output_tokens" => 20}
      }
      
      Open3.stub :popen3, -> (*args, &block) {
        # Simulate claude interaction
        stdin = StringIO.new
        stdout = StringIO.new(mock_response.to_json + "\n")
        stderr = StringIO.new
        wait_thread = Minitest::Mock.new
        wait_thread.expect :value, Process::Status.allocate.tap { |s| 
          s.instance_variable_set(:@exitstatus, 0)
          s.define_singleton_method(:success?) { true }
          s.define_singleton_method(:exitstatus) { @exitstatus }
        }
        
        block.call(stdin, stdout, stderr, wait_thread)
      } do
        runner.run("test prompt")
      end
      
      # Count temp files after - should be same (cleaned up)
      temp_files_after = Dir.glob("/tmp/claude_wrapper*.sh").count
      assert_equal temp_files_before, temp_files_after,
        "Wrapper script should be cleaned up after execution"
    end
  end
  
  def test_wrapper_script_preserves_working_directory
    Dir.mktmpdir do |tmpdir|
      # Create a test file in the temp directory
      test_file = File.join(tmpdir, "test.txt")
      File.write(test_file, "test content")
      
      runner = AutoClaude::ClaudeRunner.new(directory: tmpdir)
      
      # Mock the claude interaction
      mock_response = {
        "type" => "result",
        "subtype" => "success",
        "result" => "Working directory is correct",
        "success" => true
      }
      
      # Capture the wrapper script content
      wrapper_content = nil
      original_tempfile_new = Tempfile.method(:new)
      
      Tempfile.stub :new, -> (prefix, &block) {
        temp = original_tempfile_new.call(prefix)
        original_write = temp.method(:write)
        temp.define_singleton_method(:write) do |content|
          # Capture the wrapper script content (looking for shebang line)
          wrapper_content = content if content.start_with?("#!")
          original_write.call(content)
        end
        temp
      } do
        Open3.stub :popen3, -> (*args, &block) {
          stdin = StringIO.new
          stdout = StringIO.new(mock_response.to_json + "\n")
          stderr = StringIO.new
          wait_thread = Minitest::Mock.new
          wait_thread.expect :value, Process::Status.allocate.tap { |s| 
            s.instance_variable_set(:@exitstatus, 0)
            s.define_singleton_method(:success?) { true }
            s.define_singleton_method(:exitstatus) { @exitstatus }
          }
          
          block.call(stdin, stdout, stderr, wait_thread)
        } do
          runner.run("test")
        end
      end
      
      # Verify the wrapper script sets the correct directory
      refute_nil wrapper_content, "Should have captured wrapper script content"
      assert_includes wrapper_content, "cd \"#{tmpdir}\"",
        "Wrapper script should change to the specified directory"
      assert_includes wrapper_content, "export PWD=\"#{tmpdir}\"",
        "Wrapper script should set PWD environment variable"
      assert_includes wrapper_content, "unset OLDPWD",
        "Wrapper script should unset OLDPWD to prevent leaking parent directory"
    end
  end
  
end