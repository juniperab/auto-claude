# frozen_string_literal: true

require_relative "process/manager"
require_relative "messages/base"

module AutoClaude
  class Session
    attr_reader :messages, :result, :metadata, :error, :model_token_usage

    def initialize(directory:, output:, claude_options: [])
      @directory = directory
      @output = output
      @claude_options = claude_options
      @messages = []
      @metadata = {}
      @callbacks = []
      @result = nil
      @error = nil
      @start_time = nil
      @end_time = nil
      @model_token_usage = {}
    end

    def execute(prompt)
      @start_time = Time.now
      @output.write_divider
      @output.write_info("Working directory: #{@directory}")
      @output.write_divider

      # Show the prompt
      @output.write_user_message(prompt)

      begin
        manager = Process::Manager.new(
          directory: @directory,
          claude_options: @claude_options
        )

        manager.execute(prompt, stream_handler: method(:handle_message))

        @end_time = Time.now
        print_summary
      rescue StandardError => e
        @error = e
        @output.write_error("Error: #{e.message}")
        raise
      end

      self
    end

    def on_message(&block)
      @callbacks << block if block_given?
    end

    def success?
      !@error && @result&.success?
    end

    def error?
      !success?
    end

    def duration
      return nil unless @start_time && @end_time

      @end_time - @start_time
    end

    def cost
      @metadata["total_cost_usd"] || 0
    end

    def input_tokens
      total = 0
      @model_token_usage.each_value { |usage| total += usage[:input] }
      total
    end

    def output_tokens
      total = 0
      @model_token_usage.each_value { |usage| total += usage[:output] }
      total
    end

    def session_id
      @metadata["session_id"]
    end

    private

    def handle_message(message)
      @messages << message

      # Update session_id whenever we see it (in case it changes)
      if message.session_id
        @metadata["session_id"] = message.session_id
      end

      # Track token usage per model
      if message.model && message.token_usage
        model_name = message.model
        @model_token_usage[model_name] ||= {
          input: 0,
          output: 0,
          cache_creation: 0,
          cache_read: 0,
          count: 0
        }
        
        usage = @model_token_usage[model_name]
        usage[:input] += message.token_usage[:input]
        usage[:output] += message.token_usage[:output]
        usage[:cache_creation] += message.token_usage[:cache_creation]
        usage[:cache_read] += message.token_usage[:cache_read]
        usage[:count] += 1
      end

      # Process based on message type
      case message
      when Messages::ResultMessage
        @result = message
        @metadata = message.metadata
      when Messages::TextMessage, Messages::ToolUseMessage, Messages::ToolResultMessage
        @output.write_message(message)
      end

      # Trigger callbacks
      @callbacks.each do |callback|
        callback.call(message)
      rescue StandardError
        nil
      end
    end

    def print_summary
      return unless @result

      @output.write_divider

      if @result.success?
        @output.write_stat("Success", true)
      else
        @output.write_stat("Success", false)
        @output.write_stat("Error", @result.error_message) if @result.error_message
      end

      @output.write_stat("Turns", @metadata["num_turns"]) if @metadata["num_turns"]

      @output.write_stat("Duration", "%.1fs" % duration) if duration

      @output.write_stat("Cost", "$%.6f" % cost) if cost.positive?

      # Display per-model token usage
      @model_token_usage.each do |model, usage|
        model_display = format_model_name(model)
        tokens_str = format_token_usage(usage)
        @output.write_stat("Tokens (#{model_display})", tokens_str)
      end

      @output.write_stat("Session ID", @metadata["session_id"]) if @metadata["session_id"]

      @output.write_divider
    end

    def format_model_name(model)
      # Simplify model names for display
      case model
      when /claude-opus-4/i
        "Opus"
      when /claude-3-5-sonnet/i, /claude-sonnet/i
        "Sonnet"
      when /claude-3-5-haiku/i, /claude-haiku/i
        "Haiku"
      else
        model.split("-").first(2).join("-").capitalize
      end
    end

    def format_token_usage(usage)
      parts = []
      parts << "#{usage[:input]} in" if usage[:input].positive?
      parts << "#{usage[:output]} out" if usage[:output].positive?
      
      cache_parts = []
      cache_parts << "#{usage[:cache_creation]} created" if usage[:cache_creation].positive?
      cache_parts << "#{usage[:cache_read]} read" if usage[:cache_read].positive?
      
      result = parts.join(", ")
      result += " (cache: #{cache_parts.join(", ")})" if cache_parts.any?
      result
    end
  end
end
