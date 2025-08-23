# frozen_string_literal: true

require_relative "client"
require_relative "output/memory"

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
        max_attempts = retry_on_error ? 3 : 1 # 3 total attempts = 1 initial + 2 retries
        last_error = nil
        session = nil

        max_attempts.times do |attempt|
          # On retry, add --resume with the session ID from the failed attempt
          if attempt.positive? && session&.session_id
            # Remove any existing --resume flag
            updated_options = claude_options.reject { |opt| opt == "--resume" || opt.start_with?("--resume=") }

            # Also remove the argument after --resume if it was separate
            i = 0
            while i < updated_options.length
              if updated_options[i] == "--resume"
                updated_options.delete_at(i) # Remove --resume
                updated_options.delete_at(i) if i < updated_options.length # Remove the session ID after it
              else
                i += 1
              end
            end

            # Add the new resume flag with the session ID from the failed attempt
            updated_options = ["--resume", session.session_id] + updated_options

            # Create a new client with updated options
            client = Client.new(
              directory: directory || Dir.pwd,
              output: output_writer,
              claude_options: updated_options
            )
          end

          session = client.run(prompt)

          # Return on success
          if session.success?
            return session.result&.content || ""
          elsif !retry_on_error || attempt == max_attempts - 1
            # No retry or last attempt failed
            last_error = RuntimeError.new("Session failed")
            break
          end
          # Otherwise continue to retry
        rescue StandardError => e
          last_error = e
          if retry_on_error && attempt < max_attempts - 1
            # Continue to retry
            next
          end
        end

        raise last_error if last_error

        ""
      end

      private

      def create_output(log_file, _stderr_callback)
        outputs = []

        # Always include terminal output for backward compatibility
        terminal = Output::Terminal.new
        outputs << terminal

        # Add file output if specified
        if log_file
          begin
            outputs << Output::File.new(log_file)
          rescue StandardError => e
            warn "Warning: Could not open log file: #{e.message}"
          end
        end

        # Return appropriate output
        outputs.length == 1 ? outputs.first : Output::Multiplexer.new(outputs)
      end
    end
  end
end
