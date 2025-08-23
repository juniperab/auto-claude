# frozen_string_literal: true

module AutoClaude
  module Output
    class Writer
      def write_message(message)
        raise NotImplementedError, "Subclasses must implement write_message"
      end

      def write_user_message(text)
        raise NotImplementedError, "Subclasses must implement write_user_message"
      end

      def write_stat(key, value)
        raise NotImplementedError, "Subclasses must implement write_stat"
      end

      def write_error(error)
        raise NotImplementedError, "Subclasses must implement write_error"
      end

      def write_info(info)
        raise NotImplementedError, "Subclasses must implement write_info"
      end

      def write_divider
        raise NotImplementedError, "Subclasses must implement write_divider"
      end

      def close
        # Override if cleanup needed
      end
    end

    class Multiplexer < Writer
      def initialize(writers)
        @writers = Array(writers)
      end

      def write_message(message)
        @writers.each do |w|
          w.write_message(message)
        rescue StandardError
          nil
        end
      end

      def write_user_message(text)
        @writers.each do |w|
          w.write_user_message(text)
        rescue StandardError
          nil
        end
      end

      def write_stat(key, value)
        @writers.each do |w|
          w.write_stat(key, value)
        rescue StandardError
          nil
        end
      end

      def write_error(error)
        @writers.each do |w|
          w.write_error(error)
        rescue StandardError
          nil
        end
      end

      def write_info(info)
        @writers.each do |w|
          w.write_info(info)
        rescue StandardError
          nil
        end
      end

      def write_divider
        @writers.each do |w|
          w.write_divider
        rescue StandardError
          nil
        end
      end

      def close
        @writers.each do |w|
          w.close
        rescue StandardError
          nil
        end
      end
    end
  end
end
