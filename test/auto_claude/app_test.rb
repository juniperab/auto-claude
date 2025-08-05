require "test_helper"

class AutoClaude::AppTest < Minitest::Test
  def setup
    # Mock the ClaudeRunner to avoid actual Claude API calls
    @mock_runner = Minitest::Mock.new
    @original_claude_runner = AutoClaude::ClaudeRunner
    
    # Stub ClaudeRunner.new to return our mock
    AutoClaude::ClaudeRunner.stub :new, @mock_runner do
      yield if block_given?
    end
  end
  
  def teardown
    # Clean up any state
    AutoClaude::ColorPrinter.stderr_callback = nil
    AutoClaude::ColorPrinter.close_log_file
  end

  def test_basic_run
    # Setup mock to return a simple result
    @mock_runner.expect :run, "4", ["What is 2+2?"]
    
    AutoClaude::ClaudeRunner.stub :new, @mock_runner do
      result = AutoClaude::App.run("What is 2+2?")
      assert_equal "4", result
    end
    
    @mock_runner.verify
  end

  def test_run_with_directory
    # Setup mock with directory expectation
    expected_dir = "/tmp"
    @mock_runner.expect :run, "file1.txt file2.txt", ["List files"]
    
    # Capture the directory that was passed to ClaudeRunner.new
    actual_options = nil
    AutoClaude::ClaudeRunner.stub :new, -> (opts) { 
      actual_options = opts
      @mock_runner 
    } do
      result = AutoClaude::App.run("List files", directory: expected_dir)
      assert_equal "file1.txt file2.txt", result
      assert_equal expected_dir, actual_options[:directory]
    end
    
    @mock_runner.verify
  end

  def test_run_with_log_file
    Tempfile.create("test_log") do |tmpfile|
      @mock_runner.expect :run, "test result", ["Test prompt"]
      
      actual_options = nil
      AutoClaude::ClaudeRunner.stub :new, -> (opts) { 
        actual_options = opts
        @mock_runner 
      } do
        result = AutoClaude::App.run("Test prompt", log_file: tmpfile.path)
        assert_equal "test result", result
        assert_equal tmpfile.path, actual_options[:log_file]
      end
      
      @mock_runner.verify
    end
  end

  def test_run_with_claude_options
    @mock_runner.expect :run, "result", ["prompt"]
    
    actual_options = nil
    AutoClaude::ClaudeRunner.stub :new, -> (opts) { 
      actual_options = opts
      @mock_runner 
    } do
      result = AutoClaude::App.run("prompt", claude_options: ["--model", "opus"])
      assert_equal "result", result
      assert_equal ["--model", "opus"], actual_options[:claude_options]
    end
    
    @mock_runner.verify
  end

  def test_run_with_invalid_claude_options
    assert_raises(RuntimeError) do
      AutoClaude::App.run("test", claude_options: ["--verbose"])
    end
  end

  def test_run_with_custom_output_streams
    output = StringIO.new
    error = StringIO.new
    
    @mock_runner.expect :run, "Hello World", ["Hello"]
    
    AutoClaude::ClaudeRunner.stub :new, @mock_runner do
      result = AutoClaude::App.run("Hello", output: output, error: error)
      assert_equal "Hello World", result
    end
    
    @mock_runner.verify
  end

  def test_run_with_retry_on_error
    # First attempt fails
    error_runner = Object.new
    def error_runner.run(input)
      raise "Network error"
    end
    def error_runner.instance_variable_get(var)
      {"session_id" => "abc123"} if var == :@result_metadata
    end
    
    # Second attempt succeeds  
    success_runner = Minitest::Mock.new
    success_runner.expect :run, "Success", ["Test"]
    
    call_count = 0
    AutoClaude::ClaudeRunner.stub :new, -> (opts) {
      call_count += 1
      if call_count == 1
        error_runner
      else
        # Verify resume was added
        assert_includes opts[:claude_options], "--resume"
        assert_includes opts[:claude_options], "abc123"
        success_runner
      end
    } do
      error_output = StringIO.new
      result = AutoClaude::App.run("Test", retry_on_error: true, error: error_output)
      assert_equal "Success", result
      assert_match(/Retrying with --resume/, error_output.string)
    end
    
    success_runner.verify
  end

  def test_run_raises_on_error_without_retry
    error_runner = Object.new
    def error_runner.run(input)
      raise "Fatal error"
    end
    def error_runner.instance_variable_get(var)
      nil
    end
    
    AutoClaude::ClaudeRunner.stub :new, error_runner do
      assert_raises(RuntimeError) do
        AutoClaude::App.run("Test", retry_on_error: false)
      end
    end
  end
end