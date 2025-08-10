require 'securerandom'
require_relative 'process/manager'
require_relative 'messages/base'

module AutoClaude
    class Session
      attr_reader :id, :messages, :result, :metadata, :error

      def initialize(directory:, output:, claude_options: [])
        @id = SecureRandom.hex(8)
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
      end

      def execute(prompt)
        @start_time = Time.now
        @output.write_info("Session ID: #{@id}")
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
          
        rescue => e
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

      def token_usage
        {
          input: @metadata.dig("usage", "input_tokens") || 0,
          output: @metadata.dig("usage", "output_tokens") || 0
        }
      end

      private

      def handle_message(message)
        @messages << message
        
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
          callback.call(message) rescue nil
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
        
        if @metadata["num_turns"]
          @output.write_stat("Turns", @metadata["num_turns"])
        end
        
        if duration
          @output.write_stat("Duration", "%.1fs" % duration)
        end
        
        if cost > 0
          @output.write_stat("Cost", "$%.6f" % cost)
        end
        
        usage = token_usage
        if usage[:input] > 0 || usage[:output] > 0
          @output.write_stat("Tokens", "#{usage[:input]} up, #{usage[:output]} down")
        end
        
        @output.write_stat("Session ID", @id)
      end
  end
end