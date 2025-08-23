# frozen_string_literal: true

require "open3"
require_relative "wrapper"
require_relative "stream_parser"

module AutoClaude
  module Process
    class Manager
      def initialize(directory:, claude_options: [])
        @directory = File.expand_path(directory)
        @claude_options = claude_options || []

        validate_directory!
        validate_claude_options!
      end

      def execute(prompt, stream_handler:)
        wrapper = Wrapper.new(@directory)
        command = build_command
        script_path = wrapper.create_script(command)

        begin
          Open3.popen3(script_path) do |stdin, stdout, stderr, wait_thread|
            # Send the prompt
            stdin.puts prompt
            stdin.close

            # Parse the streaming output
            parser = StreamParser.new(stream_handler)
            parser.parse(stdout)

            # Check process exit status
            exit_status = wait_thread.value
            unless exit_status.success?
              stderr_output = stderr.read
              error_msg = "Claude process failed with exit code #{exit_status.exitstatus}"
              error_msg += ": #{stderr_output}" unless stderr_output.empty?
              raise error_msg.to_s
            end
          end
        ensure
          wrapper.cleanup
        end
      end

      private

      def validate_directory!
        return if File.directory?(@directory)

        raise ArgumentError, "Directory does not exist: #{@directory}"
      end

      def validate_claude_options!
        forbidden = %w[--verbose --output-format -p -o]

        @claude_options.each do |opt|
          if forbidden.include?(opt)
            raise ArgumentError, "Claude option '#{opt}' is managed by auto-claude and cannot be overridden"
          end
        end
      end

      def build_command
        command = ["claude", "-p", "--verbose", "--output-format", "stream-json"]
        command.concat(@claude_options)
        command
      end
    end
  end
end
