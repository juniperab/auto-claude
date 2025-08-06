require_relative '../test_helper'

class ShellSelectionTest < Minitest::Test
  
  def test_determine_shell_uses_env_zsh_when_available
    runner = AutoClaude::ClaudeRunner.new
    
    # Test when SHELL is zsh and zsh exists, with /usr/bin/env available
    ENV.stub :[], -> (key) {
      return '/bin/zsh' if key == 'SHELL'
      return '/usr/local/bin:/usr/bin:/bin' if key == 'PATH'
      nil
    } do
      File.stub :executable?, -> (path) {
        path == '/usr/bin/env' || path == '/usr/bin/zsh' || path == '/bin/bash'
      } do
        shell = runner.send(:determine_shell)
        assert_equal '/usr/bin/env zsh', shell, "Should use /usr/bin/env zsh when available"
      end
    end
  end
  
  def test_determine_shell_uses_direct_path_when_env_not_available
    runner = AutoClaude::ClaudeRunner.new
    
    # Test when /usr/bin/env is not available
    ENV.stub :[], -> (key) {
      return '/bin/zsh' if key == 'SHELL'
      return '/usr/local/bin:/usr/bin:/bin' if key == 'PATH'
      nil
    } do
      File.stub :executable?, -> (path) {
        path == '/bin/zsh' || path == '/bin/bash' # env is NOT executable
      } do
        shell = runner.send(:determine_shell)
        assert_equal '/bin/zsh', shell, "Should use direct path when /usr/bin/env not available"
      end
    end
  end
  
  def test_determine_shell_falls_back_to_env_bash_when_zsh_not_available
    runner = AutoClaude::ClaudeRunner.new
    
    # Test when SHELL is zsh but zsh doesn't exist, with /usr/bin/env available
    ENV.stub :[], -> (key) {
      return '/bin/zsh' if key == 'SHELL'
      return '/usr/local/bin:/usr/bin:/bin' if key == 'PATH'
      nil
    } do
      File.stub :executable?, -> (path) {
        path == '/usr/bin/env' || path == '/usr/bin/bash' # env and bash exist, but not zsh
      } do
        shell = runner.send(:determine_shell)
        assert_equal '/usr/bin/env bash', shell, "Should use /usr/bin/env bash when zsh not available"
      end
    end
  end
  
  def test_determine_shell_uses_env_bash_when_shell_is_not_zsh
    runner = AutoClaude::ClaudeRunner.new
    
    # Test when SHELL is bash with /usr/bin/env available
    ENV.stub :[], -> (key) {
      return '/bin/bash' if key == 'SHELL'
      return '/usr/local/bin:/usr/bin:/bin' if key == 'PATH'
      nil
    } do
      File.stub :executable?, -> (path) {
        path == '/usr/bin/env' || path == '/usr/bin/bash' || path == '/bin/zsh'
      } do
        shell = runner.send(:determine_shell)
        assert_equal '/usr/bin/env bash', shell, "Should use /usr/bin/env bash when user's shell is not zsh"
      end
    end
  end
  
  def test_which_finds_executable_in_path
    runner = AutoClaude::ClaudeRunner.new
    
    ENV.stub :[], -> (key) {
      return '/usr/local/bin:/usr/bin:/bin' if key == 'PATH'
      nil
    } do
      File.stub :executable?, -> (path) {
        path == '/usr/bin/zsh'
      } do
        result = runner.send(:which, 'zsh')
        assert_equal '/usr/bin/zsh', result
      end
    end
  end
  
  def test_which_returns_nil_when_not_found
    runner = AutoClaude::ClaudeRunner.new
    
    ENV.stub :[], -> (key) {
      return '/usr/local/bin:/usr/bin:/bin' if key == 'PATH'
      nil
    } do
      File.stub :executable?, -> (path) {
        false # Nothing is executable
      } do
        result = runner.send(:which, 'nonexistent')
        assert_nil result
      end
    end
  end
  
  def test_wrapper_script_uses_correct_shell
    skip "Skipping wrapper script content test" unless ENV['TEST_WRAPPER_CONTENT'] == '1'
    
    Dir.mktmpdir do |tmpdir|
      runner = AutoClaude::ClaudeRunner.new(directory: tmpdir)
      
      # Capture wrapper script content
      wrapper_content = nil
      original_tempfile_new = Tempfile.method(:new)
      
      Tempfile.stub :new, -> (prefix, &block) {
        temp = original_tempfile_new.call(prefix)
        original_write = temp.method(:write)
        temp.define_singleton_method(:write) do |content|
          wrapper_content = content if content.include?("#!")
          original_write.call(content)
        end
        temp
      } do
        # Mock the claude interaction
        Open3.stub :popen3, -> (*args, &block) {
          stdin = StringIO.new
          stdout = StringIO.new('{"type":"result","subtype":"success","result":"test"}' + "\n")
          stderr = StringIO.new
          wait_thread = Minitest::Mock.new
          wait_thread.expect :value, Process::Status.allocate.tap { |s| 
            s.instance_variable_set(:@exitstatus, 0)
            s.define_singleton_method(:success?) { true }
            s.define_singleton_method(:exitstatus) { @exitstatus }
          }
          
          block.call(stdin, stdout, stderr, wait_thread)
        } do
          # Force SHELL to be zsh for this test
          ENV['SHELL'] = '/bin/zsh'
          runner.run("test")
        end
      end
      
      # Check shebang line
      if File.executable?('/usr/bin/env')
        if ENV['SHELL'].end_with?('/zsh') && system('which zsh > /dev/null 2>&1')
          assert wrapper_content.start_with?("#!/usr/bin/env zsh"),
            "Wrapper script should use /usr/bin/env zsh when available"
        else
          assert wrapper_content.start_with?("#!/usr/bin/env bash"),
            "Wrapper script should use /usr/bin/env bash"
        end
      else
        # Fallback to direct paths
        if ENV['SHELL'].end_with?('/zsh') && File.executable?('/bin/zsh')
          assert wrapper_content.start_with?("#!/bin/zsh") || wrapper_content.start_with?("#!/usr/bin/zsh"),
            "Wrapper script should use direct zsh path when /usr/bin/env not available"
        else
          assert wrapper_content.start_with?("#!/bin/bash") || wrapper_content.start_with?("#!/usr/bin/bash"),
            "Wrapper script should use direct bash path"
        end
      end
    end
  end
end