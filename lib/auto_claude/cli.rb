require_relative 'client'
require_relative 'output/terminal'
require_relative 'output/file'
require_relative 'output/writer'

module AutoClaude
    class CLI
      def self.run(args = ARGV)
        options = parse_arguments(args)
        
        # Handle help
        if options[:help]
          show_help
          exit(0)
        end
        
        # Get prompt
        prompt = options[:prompt] || read_stdin
        if prompt.nil? || prompt.empty?
          $stderr.puts "Error: No prompt provided"
          show_usage
          exit(1)
        end
        
        # Create output
        output = create_output(options)
        
        # Create client and run
        client = Client.new(
          directory: options[:directory] || Dir.pwd,
          output: output,
          claude_options: options[:claude_options] || []
        )
        
        # Handle retry logic
        max_attempts = options[:retry_on_error] ? 3 : 1  # 3 total attempts = 1 initial + 2 retries
        session = nil
        
        max_attempts.times do |attempt|
          begin
            # On retry, add --resume with the session ID from the failed attempt
            if attempt > 0 && session&.session_id
              # Remove any existing --resume flag and add the new one
              claude_opts = options[:claude_options].reject { |opt| opt == "--resume" || opt.start_with?("--resume=") }
              
              # Also remove the argument after --resume if it was separate
              i = 0
              while i < claude_opts.length
                if claude_opts[i] == "--resume"
                  claude_opts.delete_at(i) # Remove --resume
                  claude_opts.delete_at(i) if i < claude_opts.length # Remove the session ID after it
                else
                  i += 1
                end
              end
              
              # Add the new resume flag with the session ID from the failed attempt
              claude_opts = ["--resume", session.session_id] + claude_opts
              
              # Create a new client with updated options
              client = Client.new(
                directory: options[:directory] || Dir.pwd,
                output: output,
                claude_options: claude_opts
              )
              
              output.write_info("Retrying with session ID: #{session.session_id}")
              output.write_divider
            end
            
            session = client.run(prompt)
            
            # If successful, break out of retry loop
            if session.success?
              break
            elsif !options[:retry_on_error] || attempt == max_attempts - 1
              # No retry or last attempt failed
              $stderr.puts "Error: Session failed"
              exit(1)
            end
            # Otherwise continue to retry
            
          rescue => e
            if options[:retry_on_error] && attempt < max_attempts - 1
              $stderr.puts "Error on attempt #{attempt + 1}: #{e.message}"
              # Continue to retry
            else
              $stderr.puts "Error: #{e.message}"
              exit(1)
            end
          end
        end
        
        # Print result to stdout
        if session&.result
          puts session.result.content unless session.result.content.empty?
          
          # Write metadata to log file if specified
          if options[:log_file] && output.is_a?(Output::Multiplexer)
            file_output = output.instance_variable_get(:@writers).find { |w| w.is_a?(Output::File) }
            file_output.write_metadata(session.metadata) if file_output
          end
          
          exit(0)
        else
          exit(1)
        end
        
      ensure
        output.close rescue nil
      end

      private

      def self.parse_arguments(args)
        options = {
          directory: nil,
          log_file: nil,
          claude_options: [],
          prompt: nil,
          help: false,
          retry_on_error: false
        }
        
        i = 0
        while i < args.length
          arg = args[i]
          
          case arg
          when "-h", "--help"
            options[:help] = true
          when "-d", "--directory"
            i += 1
            if i >= args.length
              raise ArgumentError, "#{arg} requires a directory argument"
            end
            options[:directory] = args[i]
          when "-l", "--log"
            i += 1
            if i >= args.length
              raise ArgumentError, "#{arg} requires a file argument"
            end
            options[:log_file] = args[i]
          when "-r", "--retry"
            options[:retry_on_error] = true
          when "--"
            # Everything after -- is claude options
            options[:claude_options] = args[(i + 1)..-1]
            break
          else
            if arg.start_with?("-")
              raise ArgumentError, "Unrecognized option '#{arg}'"
            else
              # It's the prompt
              if options[:prompt].nil?
                options[:prompt] = arg
              else
                raise ArgumentError, "Too many arguments"
              end
            end
          end
          
          i += 1
        end
        
        options
      end

      def self.create_output(options)
        outputs = []
        
        # Always include terminal output
        outputs << Output::Terminal.new
        
        # Add file output if specified
        if options[:log_file]
          begin
            outputs << Output::File.new(options[:log_file])
          rescue => e
            $stderr.puts "Warning: Could not open log file: #{e.message}"
          end
        end
        
        # Return single output or multiplexer
        outputs.length == 1 ? outputs.first : Output::Multiplexer.new(outputs)
      end

      def self.read_stdin
        return nil unless $stdin.stat.pipe? || $stdin.stat.size > 0
        $stdin.read
      rescue
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