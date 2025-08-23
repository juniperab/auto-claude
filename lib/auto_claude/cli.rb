# frozen_string_literal: true

require_relative "client"
require_relative "output/terminal"
require_relative "output/file"
require_relative "output/writer"

module AutoClaude
  class CLI
    def self.run(args = ARGV)
      options = parse_arguments(args)
      handle_help(options)

      prompt = get_prompt(options)
      output = create_output(options)

      session = run_with_retry(prompt, options, output)
      handle_result(session, options, output)
    ensure
      close_output(output)
    end

    def self.handle_help(options)
      return unless options[:help]

      show_help
      exit(0)
    end

    def self.get_prompt(options)
      prompt = options[:prompt] || read_stdin
      return prompt if prompt && !prompt.empty?

      warn "Error: No prompt provided"
      show_usage
      exit(1)
    end

    def self.run_with_retry(prompt, options, output)
      max_attempts = options[:retry_on_error] ? 3 : 1
      session = nil

      max_attempts.times do |attempt|
        client = create_client_for_attempt(attempt, session, options, output)

        session = client.run(prompt)

        if session.success?
          return session
        elsif !options[:retry_on_error] || attempt == max_attempts - 1
          warn "Error: Session failed"
          exit(1)
        end
      rescue StandardError => e
        handle_attempt_error(e, attempt, max_attempts, options)
      end

      session
    end

    def self.create_client_for_attempt(attempt, session, options, output)
      claude_opts = if attempt.positive? && session&.session_id
                      prepare_resume_options(session, options, output)
                    else
                      options[:claude_options] || []
                    end

      Client.new(
        directory: options[:directory] || Dir.pwd,
        output: output,
        claude_options: claude_opts
      )
    end

    def self.prepare_resume_options(session, options, output)
      claude_opts = remove_existing_resume_flags(options[:claude_options])
      claude_opts = ["--resume", session.session_id] + claude_opts

      output.write_info("Retrying with session ID: #{session.session_id}")
      output.write_divider

      claude_opts
    end

    def self.remove_existing_resume_flags(claude_options)
      opts = claude_options.reject { |opt| opt == "--resume" || opt.start_with?("--resume=") }

      # Remove the argument after --resume if it was separate
      i = 0
      while i < opts.length
        if opts[i] == "--resume"
          opts.delete_at(i) # Remove --resume
          opts.delete_at(i) if i < opts.length # Remove the session ID after it
        else
          i += 1
        end
      end

      opts
    end

    def self.handle_attempt_error(error, attempt, max_attempts, options)
      if options[:retry_on_error] && attempt < max_attempts - 1
        warn "Error on attempt #{attempt + 1}: #{error.message}"
      else
        warn "Error: #{error.message}"
        exit(1)
      end
    end

    def self.handle_result(session, options, output)
      exit(1) unless session&.result

      puts session.result.content unless session.result.content.empty?

      write_log_metadata(session, options, output)
      exit(0)
    end

    def self.write_log_metadata(session, options, output)
      return unless options[:log_file] && output.is_a?(Output::Multiplexer)

      file_output = output.instance_variable_get(:@writers).find { |w| w.is_a?(Output::File) }
      file_output&.write_metadata(session.metadata)
    end

    def self.close_output(output)
      output&.close
    rescue StandardError
      nil
    end

    def self.parse_arguments(args)
      options = default_options
      i = 0

      while i < args.length
        arg = args[i]
        i = process_argument(arg, args, i, options)
        break if options[:claude_options].any? # Stop if we hit --

        i += 1
      end

      options
    end

    def self.default_options
      {
        directory: nil,
        log_file: nil,
        claude_options: [],
        prompt: nil,
        help: false,
        retry_on_error: false
      }
    end

    def self.process_argument(arg, args, index, options)
      case arg
      when "-h", "--help"
        options[:help] = true
        index
      when "-d", "--directory"
        options[:directory] = get_required_arg(arg, args, index + 1)
        index + 1
      when "-l", "--log"
        options[:log_file] = get_required_arg(arg, args, index + 1)
        index + 1
      when "-r", "--retry"
        options[:retry_on_error] = true
        index
      when "--"
        options[:claude_options] = args[(index + 1)..]
        args.length # Force loop to end
      else
        handle_positional_arg(arg, options)
        index
      end
    end

    def self.get_required_arg(flag, args, index)
      raise ArgumentError, "#{flag} requires an argument" if index >= args.length

      args[index]
    end

    def self.handle_positional_arg(arg, options)
      raise ArgumentError, "Unrecognized option '#{arg}'" if arg.start_with?("-")
      raise ArgumentError, "Too many arguments" unless options[:prompt].nil?

      options[:prompt] = arg
    end

    def self.create_output(options)
      outputs = []

      # Always include terminal output
      outputs << Output::Terminal.new

      # Add file output if specified
      if options[:log_file]
        begin
          outputs << Output::File.new(options[:log_file])
        rescue StandardError => e
          warn "Warning: Could not open log file: #{e.message}"
        end
      end

      # Return single output or multiplexer
      outputs.length == 1 ? outputs.first : Output::Multiplexer.new(outputs)
    end

    def self.read_stdin
      return nil unless $stdin.stat.pipe? || $stdin.stat.size.positive?

      $stdin.read
    rescue StandardError
      nil
    end

    def self.show_help
      puts <<~HELP
        Usage: auto-claude [OPTIONS] [PROMPT]
               auto-claude < input.txt
               echo 'text' | auto-claude

        OPTIONS:
          -h, --help              Show this help message
          -d, --directory DIR     Run claude in specified directory
          -l, --log FILE          Save output to log file
          -r, --retry             Retry twice on error with --resume (3 total attempts)
          --                      Pass remaining args to claude

        EXAMPLES:
          auto-claude "What is 2+2?"
          auto-claude -d /tmp "List files"
          auto-claude -l session.log "Generate a README"
          auto-claude "Complex task" -- --model opus --temperature 0.7
          echo "Explain this code" | auto-claude
          auto-claude < prompt.txt

        For more information, visit: https://github.com/juniperab/auto-claude
      HELP
    end

    def self.show_usage
      puts "Usage: auto-claude [OPTIONS] [PROMPT]"
      puts "Try 'auto-claude --help' for more information."
    end
  end
end
