# frozen_string_literal: true

module AutoClaude
  module Output
    module Formatters
      class Base
        def initialize(config = FormatterConfig.new)
          @config = config
        end

        def format(input)
          raise NotImplementedError, "Subclasses must implement #format"
        end

        protected

        def extract_value(input, *keys)
          return nil unless input.is_a?(Hash)

          keys.each do |key|
            value = input[key] || input[key.to_s] || input[key.to_sym]
            return value if value
          end
          nil
        end

        def truncate_path(path, max_length = 60)
          return "unknown" if path.nil? || path.empty?
          return path if path.length <= max_length

          parts = path.split("/")
          return "...#{path[(-max_length + 3)..]}" if parts.length <= 2

          ".../#{parts.last(2).join("/")}"
        end
      end
    end
  end
end
