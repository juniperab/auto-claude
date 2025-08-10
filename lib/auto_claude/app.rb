require_relative 'client'
require_relative 'output/memory'

module AutoClaude
  # Backward compatibility wrapper for V1 API
  class App
    class << self
      # Main entry point for backward compatibility
      # Returns just the string result like V1 did
      def run(prompt, directory: nil, log_file: nil, claude_options: [], 
              output: nil, error: nil, stderr_callback: nil, retry_on_error: false)
        
        # Create output based on options
        output_writer = create_output(log_file, stderr_callback)
        
        # Create client
        client = Client.new(
          directory: directory || Dir.pwd,
          output: output_writer,
          claude_options: claude_options
        )
        
        # Handle retry logic
        max_attempts = retry_on_error ? 2 : 1
        last_error = nil
        
        max_attempts.times do |attempt|
          begin
            session = client.run(prompt)
            return session.result&.content || ""
          rescue => e
            last_error = e
            if retry_on_error && attempt == 0
              # Could add retry logic here if needed
              next
            end
          end
        end
        
        raise last_error if last_error
        ""
      end
      
      private
      
      def create_output(log_file, stderr_callback)
        outputs = []
        
        # Always include terminal output for backward compatibility
        terminal = Output::Terminal.new
        outputs << terminal
        
        # Add file output if specified
        if log_file
          begin
            outputs << Output::File.new(log_file)
          rescue => e
            $stderr.puts "Warning: Could not open log file: #{e.message}"
          end
        end
        
        # Return appropriate output
        outputs.length == 1 ? outputs.first : Output::Multiplexer.new(outputs)
      end
    end
  end
end