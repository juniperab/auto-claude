require_relative 'client'
require_relative 'output/terminal'
require_relative 'output/file'
require_relative 'output/writer'

module AutoClaude
  module V2
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
        
        begin
          session = client.run(prompt)
          
          # Print result to stdout
          if session.result
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
          
        rescue => e
          $stderr.puts "Error: #{e.message}"
          exit(1)
        ensure
          output.close rescue nil
        end
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
            -r, --retry             Retry on error with --resume
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
end