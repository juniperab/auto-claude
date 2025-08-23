# frozen_string_literal: true

require "securerandom"
require_relative "session"
require_relative "output/terminal"

module AutoClaude
  class Client
    attr_reader :sessions

    def initialize(directory: Dir.pwd, output: nil, claude_options: [])
      @directory = File.expand_path(directory)
      @output = output || Output::Terminal.new
      @claude_options = claude_options || []
      @sessions = []

      validate_directory!
    end

    def run(prompt, claude_options: nil, &)
      options = claude_options || @claude_options

      session = Session.new(
        directory: @directory,
        output: @output,
        claude_options: options
      )

      session.on_message(&) if block_given?

      session.execute(prompt)
      @sessions << session

      session
    end

    def run_async(prompt, claude_options: nil, &)
      Thread.new { run(prompt, claude_options: claude_options, &) }
    end

    private

    def validate_directory!
      return if File.directory?(@directory)

      raise ArgumentError, "Directory does not exist: #{@directory}"
    end
  end
end
