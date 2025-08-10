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
          @writers.each { |w| w.write_message(message) rescue nil }
        end

        def write_user_message(text)
          @writers.each { |w| w.write_user_message(text) rescue nil }
        end

        def write_stat(key, value)
          @writers.each { |w| w.write_stat(key, value) rescue nil }
        end

        def write_error(error)
          @writers.each { |w| w.write_error(error) rescue nil }
        end

        def write_info(info)
          @writers.each { |w| w.write_info(info) rescue nil }
        end

        def write_divider
          @writers.each { |w| w.write_divider rescue nil }
        end

        def close
          @writers.each { |w| w.close rescue nil }
        end
      end
  end
end