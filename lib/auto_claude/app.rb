require "thor"

module AutoClaude
  class App < Thor
    package_name "auto-claude"

    # Hide Thor's built-in help
    remove_command :help

    class << self
      def exit_on_failure?
        true
      end

      # Override start to handle our custom argument parsing
      def start(given_args = ARGV, config = {})
        # Split arguments at '--' if present
        prompt = nil
        claude_options = []
        directory = nil

        if given_args.include?("--")
          separator_index = given_args.index("--")
          main_args = given_args[0...separator_index]
          claude_options = given_args[(separator_index + 1)..-1]
        else
          main_args = given_args
        end

        # Parse main arguments
        i = 0
        log_file = nil
        retry_on_error = false
        while i < main_args.length
          arg = main_args[i]

          if arg == "-h" || arg == "--help"
            show_help
            exit(0)
          elsif arg == "-d" || arg == "--directory"
            # Get the next argument as the directory
            i += 1
            if i >= main_args.length
              puts "Error: #{arg} requires a directory argument"
              show_usage_error
              exit(1)
            end
            directory = main_args[i]
          elsif arg == "-l" || arg == "--log"
            # Get the next argument as the log file
            i += 1
            if i >= main_args.length
              puts "Error: #{arg} requires a file argument"
              show_usage_error
              exit(1)
            end
            log_file = main_args[i]
          elsif arg == "-r" || arg == "--retry"
            retry_on_error = true
          elsif arg.start_with?("-")
            puts "Error: Unrecognized option '#{arg}'"
            show_usage_error
            exit(1)
          else
            # It's a prompt
            if prompt.nil?
              prompt = arg
            else
              puts "Error: Too many arguments"
              show_usage_error
              exit(1)
            end
          end

          i += 1
        end

        # Validate claude options
        if !claude_options.empty?
          error = validate_claude_options(claude_options)
          if error
            puts "Error: #{error}"
            exit(1)
          end
        end

        # Create app instance and process
        app = new([], {}, {})
        app.instance_variable_set(:@claude_options, claude_options)
        app.instance_variable_set(:@directory, directory)
        app.instance_variable_set(:@log_file, log_file)
        app.instance_variable_set(:@retry_on_error, retry_on_error)
        app.process(prompt)
        exit(0)
      end

      def show_usage_error
        puts "Usage: auto-claude [OPTIONS] [PROMPT]"
        puts "       auto-claude < input.txt"
        puts "       echo 'text' | auto-claude"
        puts ""
        puts "Run 'auto-claude -h' or 'auto-claude --help' for more information."
      end

      def show_help
        puts "auto-claude - Run Claude non-interactively and format its streaming output"
        puts ""
        puts "Usage: auto-claude [OPTIONS] [PROMPT] [-- CLAUDE_OPTIONS]"
        puts "       auto-claude < input.txt"
        puts "       echo 'text' | auto-claude"
        puts ""
        puts "Options:"
        puts "  -h, --help              Show this help message"
        puts "  -d, --directory DIR     Set working directory for claude command"
        puts "  -l, --log FILE          Log all messages to FILE"
        puts "  -r, --retry             Retry up to 3 times on error using --resume"
        puts "  --                      Pass remaining arguments to claude command"
        puts ""
        puts "Examples:"
        puts "  auto-claude \"What is 2+2?\"                    # Quick prompt"
        puts "  auto-claude -d /tmp \"List files\"               # Run in /tmp directory"
        puts "  auto-claude < input.txt                        # Read from file"
        puts "  cat input.txt | auto-claude                    # Pipe from command"
        puts "  auto-claude \"prompt\" -- --model opus           # Pass options to claude"
      end

      def validate_claude_options(options)
        # Define forbidden options
        forbidden_flags = {
          "--verbose" => "The --verbose flag conflicts with auto-claude's output formatting",
          "-p" => "The -p/--print flag conflicts with auto-claude's output handling",
          "--print" => "The -p/--print flag conflicts with auto-claude's output handling",
          "--output-format" => "The --output-format flag is managed by auto-claude",
          "--input-format" => "The --input-format flag is managed by auto-claude",
          "-v" => "The -v/--version flag cannot be passed through",
          "--version" => "The -v/--version flag cannot be passed through",
          "-h" => "The -h/--help flag cannot be passed through",
          "--help" => "The -h/--help flag cannot be passed through"
        }

        i = 0
        while i < options.length
          opt = options[i]

          # Check if it's a forbidden flag
          if forbidden_flags.has_key?(opt)
            return forbidden_flags[opt]
          end

          # Check if it's a non-option argument (doesn't start with -)
          # But skip this check if the previous argument was an option that takes a value
          if !opt.start_with?("-")
            # Check if this is a value for the previous option
            if i > 0 && options[i-1].start_with?("-")
              # This is likely a value for the previous option, which is fine
            else
              return "Cannot pass non-option arguments to claude (found: '#{opt}'). Only flags starting with '-' are allowed."
            end
          end

          i += 1
        end

        nil # No errors
      end

      # Programmatic entrypoint for Ruby applications
      # 
      # @param prompt [String] The prompt to send to Claude
      # @param directory [String, nil] Working directory for Claude command
      # @param log_file [String, nil] Path to log file for all messages
      # @param retry_on_error [Boolean] Retry up to 3 times on error using --resume
      # @param claude_options [Array<String>] Additional options to pass to Claude
      # @param output [IO] IO object to write output to (defaults to $stdout)
      # @param error [IO] IO object to write errors to (defaults to $stderr)
      # @param stderr_callback [Proc, nil] Callback for streaming stderr messages
      #   The callback receives (message, type, color) where:
      #   - message: the stderr message string
      #   - type: :message or :stat
      #   - color: the color symbol (:cyan, :blue, :red, etc.)
      # 
      # @return [String] The result from Claude
      # @raise [RuntimeError] If Claude command fails
      #
      # @example Basic usage
      #   result = AutoClaude::App.run("What is 2+2?")
      #
      # @example With options
      #   result = AutoClaude::App.run(
      #     "List files",
      #     directory: "/tmp",
      #     log_file: "/tmp/claude.log",
      #     retry_on_error: true,
      #     claude_options: ["--model", "opus"]
      #   )
      #
      # @example Capturing output to a StringIO
      #   output = StringIO.new
      #   result = AutoClaude::App.run("Hello", output: output)
      #   captured_output = output.string
      #
      # @example With streaming stderr callback
      #   AutoClaude::App.run(
      #     "Generate some code",
      #     stderr_callback: -> (msg, type, color) { 
      #       puts "[#{type}] #{msg}" 
      #     }
      #   )
      def run(prompt, directory: nil, log_file: nil, retry_on_error: false, claude_options: [], output: $stdout, error: $stderr, stderr_callback: nil)
        # Validate claude options
        if !claude_options.empty?
          validation_error = validate_claude_options(claude_options)
          if validation_error
            raise "Invalid claude options: #{validation_error}"
          end
        end

        # Temporarily redirect stdout and stderr
        original_stdout = $stdout
        original_stderr = $stderr
        original_stderr_callback = ColorPrinter.stderr_callback
        
        begin
          $stdout = output
          $stderr = error
          ColorPrinter.stderr_callback = stderr_callback

          # Create app instance and configure
          app = new([], {}, {})
          app.instance_variable_set(:@claude_options, claude_options)
          app.instance_variable_set(:@directory, directory)
          app.instance_variable_set(:@log_file, log_file)
          app.instance_variable_set(:@retry_on_error, retry_on_error)
          
          # Capture the result instead of printing it
          result = nil
          app.define_singleton_method(:process) do |input|
            # Run claude with the prompt
            max_attempts = @retry_on_error ? 3 : 1
            attempt = 0
            last_session_id = nil

            while attempt < max_attempts
              attempt += 1

              # Add --resume option if we have a session ID from previous attempt
              claude_opts = @claude_options || []
              if last_session_id && attempt > 1
                # Check if --resume is already in options
                unless claude_opts.any? { |opt| opt == "--resume" }
                  claude_opts = claude_opts + ["--resume", last_session_id]
                  retry_msg = "  Retrying with --resume #{last_session_id} (attempt #{attempt}/#{max_attempts})..."
                  $stderr.puts retry_msg
                  ColorPrinter.stderr_callback&.call("#{retry_msg}\n", :message, :cyan)
                end
              end

              begin
                runner = ClaudeRunner.new(claude_options: claude_opts, directory: @directory, log_file: @log_file)
                result = runner.run(input)
                return result # Return instead of puts
              rescue => e
                # Try to extract session_id from the runner
                last_session_id = runner.instance_variable_get(:@result_metadata)&.dig("session_id")

                if attempt < max_attempts && @retry_on_error
                  error_msg = "  Error occurred: #{e.message}"
                  $stderr.puts error_msg
                  ColorPrinter.stderr_callback&.call("#{error_msg}\n", :message, :red)
                  sleep(1) # Small delay before retry
                else
                  # Final attempt failed or no retry option
                  raise e
                end
              end
            end
          end
          
          # Run the process and return the result
          app.process(prompt)
        ensure
          # Restore original stdout and stderr
          $stdout = original_stdout
          $stderr = original_stderr
          ColorPrinter.stderr_callback = original_stderr_callback
        end
      end
    end

    desc "[PROMPT]", "Run Claude non-interactively"
    def process(prompt = nil)
      # Read from stdin if no prompt provided
      if prompt.nil?
        if $stdin.tty?
          # Interactive mode - read until EOF (Ctrl-D)
          input = $stdin.read
        else
          # Piped input
          input = $stdin.read
        end
      else
        input = prompt
      end

      # Run claude with the prompt
      max_attempts = @retry_on_error ? 3 : 1
      attempt = 0
      last_session_id = nil

      while attempt < max_attempts
        attempt += 1

        # Add --resume option if we have a session ID from previous attempt
        claude_options = @claude_options || []
        if last_session_id && attempt > 1
          # Check if --resume is already in options
          unless claude_options.any? { |opt| opt == "--resume" }
            claude_options = claude_options + ["--resume", last_session_id]
            $stderr.puts "  Retrying with --resume #{last_session_id} (attempt #{attempt}/#{max_attempts})..."
          end
        end

        begin
          runner = ClaudeRunner.new(claude_options: claude_options, directory: @directory, log_file: @log_file)
          result = runner.run(input)
          puts result
          return # Success - exit the method
        rescue => e
          # Try to extract session_id from the runner
          last_session_id = runner.instance_variable_get(:@result_metadata)&.dig("session_id")

          if attempt < max_attempts && @retry_on_error
            $stderr.puts "  Error occurred: #{e.message}"
            sleep(1) # Small delay before retry
          else
            # Final attempt failed or no retry option
            $stderr.puts "  Error: #{e.message}"
            exit(1)
          end
        end
      end
    end

    default_task :process
  end
end
