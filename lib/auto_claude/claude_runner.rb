require "json"
require "open3"
require "active_support/all"
require "tempfile"

module AutoClaude
  class ClaudeRunner

    def initialize(claude_options: [], directory: nil, log_file: nil)
      @claude_options = claude_options
      @directory = directory
      @log_file = log_file
      @result_metadata = nil
      @error = nil

      # Initialize log file if provided
      if @log_file
        ColorPrinter.set_log_file(@log_file)
      end
    end

    def run(prompt)
      ColorPrinter.print_message "---", color: :cyan

      # Determine the working directory
      working_dir = @directory || Dir.pwd
      
      # Validate directory exists
      raise "Directory does not exist: #{working_dir}" unless File.directory?(working_dir)
      
      # Print working directory if specified
      if @directory
        ColorPrinter.print_message "Working directory: #{working_dir}", color: :dark_gray
      end
      
      # Print log file location if provided
      if @log_file
        ColorPrinter.print_message "Log file: #{@log_file}", color: :dark_gray
      end
      
      result = run_internal(prompt, working_dir)

      ColorPrinter.print_message "---", color: :cyan

      # Write JSON metadata to log file if available
      if @log_file && @result_metadata
        write_metadata_json
      end

      # Raise error after all logging is complete
      raise @error unless @error.nil?

      result
    ensure
      # Close log file if it was opened
      ColorPrinter.close_log_file if @log_file
    end

    private

    def run_internal(prompt, working_dir)
      print_prompt prompt
      run_with_wrapper_script(prompt, working_dir)
    end

    def run_with_wrapper_script(prompt, working_dir)
      # Create a temporary shell script that changes directory before running claude
      wrapper_script = Tempfile.new(['claude_wrapper', '.sh'])
      begin
        # Build the claude command
        command = build_command
        claude_command = command.map { |arg| "'#{arg.gsub("'", "'\\''")}'" }.join(" ")
        
        # Determine the shell to use - prefer user's default shell if it's zsh
        shell = determine_shell
        
        # Write the wrapper script
        wrapper_script.write(<<~SCRIPT)
          #!#{shell}
          cd "#{working_dir}"
          # Clear some environment variables that might leak parent directory info
          unset OLDPWD
          export PWD="#{working_dir}"
          # Remove any Ruby-related env vars that might contain paths
          unset BUNDLE_GEMFILE
          unset BUNDLE_BIN_PATH
          unset RUBYLIB
          unset RUBYOPT
          # Execute claude
          exec #{claude_command}
        SCRIPT
        wrapper_script.close
        
        # Make the script executable
        File.chmod(0755, wrapper_script.path)
        
        result = ""
        
        # Execute the wrapper script
        Open3.popen3(wrapper_script.path) do |stdin, stdout, stderr, wait_thread|
          result = process_claude_interaction(stdin, stdout, stderr, wait_thread, prompt)
        end
        
        result
      ensure
        # Clean up the wrapper script
        wrapper_script.unlink
      end
    end


    def determine_shell
      # Check if user's shell is zsh
      user_shell = ENV['SHELL'] || ''
      
      # Check if /usr/bin/env exists for more portable shebangs
      if File.executable?('/usr/bin/env')
        if user_shell.end_with?('/zsh') && which('zsh')
          return '/usr/bin/env zsh'
        else
          return '/usr/bin/env bash'
        end
      end
      
      # Fall back to direct paths if /usr/bin/env is not available
      if user_shell.end_with?('/zsh')
        # Verify zsh exists and is executable
        zsh_path = which('zsh') || '/bin/zsh'
        return zsh_path if File.executable?(zsh_path)
      end
      
      # Fall back to bash
      bash_path = which('bash') || '/bin/bash'
      bash_path
    end
    
    def which(cmd)
      # Simple which implementation to find executable in PATH
      ENV['PATH'].split(':').each do |path|
        exe = File.join(path, cmd)
        return exe if File.executable?(exe)
      end
      nil
    end
    
    def process_claude_interaction(stdin, stdout, stderr, wait_thread, prompt)
      result = ""
      
      # Write prompt and close stdin
      stdin.write(prompt)
      stdin.close

      # Process streaming output
      stdout.each_line do |line|
        json = parse_json(line)
        next unless json

        case json["type"]
        when "assistant", "user"
          MessageFormatter.format_and_print_messages(json)
        when "result"
          result += handle_result(json) || ""
        when "system"
          # Ignore system messages
        else
          $stderr.puts "Warning: Unexpected message type: #{json["type"]}"
        end
      end

      # Check for errors
      exit_status = wait_thread.value
      unless exit_status.success?
        error_output = stderr.read
        @error = "Claude command failed with exit code #{exit_status.exitstatus}: #{error_output}"
        # Create minimal metadata for logging
        @result_metadata ||= {}
        @result_metadata["success"] = false
        @result_metadata["error_message"] = @error
      end

      if @result_metadata
        print_usage_stats
      end

      result
    end

    def build_command
      # Base command with required flags for streaming JSON
      command = %w[claude -p --verbose --output-format stream-json]

      # Add user-provided options
      command.concat(@claude_options)

      command
    end

    def parse_json(line)
      JSON.parse(line)
    rescue JSON::ParserError
      nil
    end

    def handle_result(json)
      if json["is_error"]
        error_msg = json["result"] || json.dig("error", "message") || "Unknown error"
        @error = "Claude error: #{error_msg}"
        # Store error info in metadata
        @result_metadata = json.merge("success" => false, "error_message" => error_msg)
      elsif json["subtype"] == "success"
        # Store success info in metadata
        @result_metadata = json.merge("success" => true)
        return json["result"] || ""
      else
        @error = "Claude did not complete successfully: #{json.inspect}"
        @result_metadata = json.merge("success" => false, "error_message" => @error)
      end
      nil
    end


    def print_usage_stats
      return unless @result_metadata

      cost = @result_metadata["total_cost_usd"] || 0
      num_turns = @result_metadata["num_turns"] || 0
      duration_ms = @result_metadata["duration_ms"] || 0
      input_tokens = @result_metadata.dig("usage", "input_tokens") || 0
      output_tokens = @result_metadata.dig("usage", "output_tokens") || 0
      session_id = @result_metadata["session_id"]

      duration_seconds = duration_ms / 1000.0

      # Print stats in dark gray
      success = @result_metadata["success"]
      ColorPrinter.print_stat "Success: #{success}"
      ColorPrinter.print_stat "Turns: #{num_turns}" if num_turns > 0
      ColorPrinter.print_stat "Duration: #{'%.1f' % duration_seconds}s" if duration_ms > 0
      ColorPrinter.print_stat "Cost: $#{'%.6f' % cost}"
      ColorPrinter.print_stat "Tokens: #{input_tokens} up, #{output_tokens} down"
      ColorPrinter.print_stat "Session ID: #{session_id}" if session_id
    end

    def print_prompt(prompt, max_lines: 5)
      ColorPrinter.print_message prompt, color: :blue, max_lines: max_lines
    end

    def write_metadata_json
      return unless @result_metadata

      # Extract metadata
      metadata = {
        success: @result_metadata["success"],
        turns: @result_metadata["num_turns"] || 0,
        duration_ms: @result_metadata["duration_ms"] || 0,
        duration_s: (@result_metadata["duration_ms"] || 0) / 1000.0,
        cost_usd: @result_metadata["total_cost_usd"] || 0,
        input_tokens: @result_metadata["usage"]["input_tokens"] || 0,
        output_tokens: @result_metadata["usage"]["output_tokens"] || 0,
        session_id: @result_metadata["session_id"]
      }

      # Add error message if present
      if @result_metadata["error_message"]
        metadata[:error_message] = @result_metadata["error_message"]
      end

      # Write JSON on a single line
      ColorPrinter.log_to_file(metadata.to_json)
    end
  end
end
