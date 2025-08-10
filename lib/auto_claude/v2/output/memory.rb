require_relative 'writer'

module AutoClaude
  module V2
    module Output
      class Memory < Writer
        attr_reader :messages, :stats, :errors, :info, :user_messages

        def initialize
          @messages = []
          @user_messages = []
          @stats = {}
          @errors = []
          @info = []
          @dividers = 0
        end

        def write_message(message)
          @messages << message
        end

        def write_user_message(text)
          @user_messages << text
        end

        def write_stat(key, value)
          @stats[key] = value
        end

        def write_error(error)
          @errors << error
        end

        def write_info(info)
          @info << info
        end

        def write_divider
          @dividers += 1
        end

        def clear
          @messages.clear
          @user_messages.clear
          @stats.clear
          @errors.clear
          @info.clear
          @dividers = 0
        end

        def to_s
          output = []
          output << "User Messages: #{@user_messages.join(', ')}" if @user_messages.any?
          output << "Messages: #{@messages.count}" if @messages.any?
          output << "Stats: #{@stats.inspect}" if @stats.any?
          output << "Errors: #{@errors.join(', ')}" if @errors.any?
          output << "Info: #{@info.join(', ')}" if @info.any?
          output.join("\n")
        end
      end
    end
  end
end