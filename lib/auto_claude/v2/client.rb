require 'securerandom'
require_relative 'session'
require_relative 'output/terminal'

module AutoClaude
  module V2
    class Client
      attr_reader :sessions

      def initialize(directory: Dir.pwd, output: nil, claude_options: [])
        @directory = File.expand_path(directory)
        @output = output || Output::Terminal.new
        @claude_options = claude_options || []
        @sessions = []
        
        validate_directory!
      end

      def run(prompt, claude_options: nil, &block)
        options = claude_options || @claude_options
        
        session = Session.new(
          directory: @directory,
          output: @output,
          claude_options: options
        )
        
        session.on_message(&block) if block_given?
        
        result = session.execute(prompt)
        @sessions << session
        
        session
      end

      def run_async(prompt, claude_options: nil, &block)
        Thread.new { run(prompt, claude_options: claude_options, &block) }
      end

      private

      def validate_directory!
        unless File.directory?(@directory)
          raise ArgumentError, "Directory does not exist: #{@directory}"
        end
      end
    end
  end
end