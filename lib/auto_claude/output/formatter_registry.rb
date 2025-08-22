module AutoClaude
  module Output
    class FormatterRegistry
      def initialize(config = FormatterConfig.new)
        @config = config
        @formatters = {}
        @file_formatter = Formatters::File.new(config)
        @search_formatter = Formatters::Search.new(config)
        @web_formatter = Formatters::Web.new(config)
        register_defaults
      end
      
      def format_tool(tool_name, input)
        return format_mcp_tool(tool_name, input) if tool_name&.start_with?("mcp__")
        
        formatter = @formatters[tool_name.to_s.downcase]
        formatter ? formatter.format(input) : default_format(tool_name, input)
      end
      
      private
      
      def register_defaults
        # Execution
        @formatters["bash"] = Formatters::Bash.new(@config)
        
        # File operations (delegated to File formatter)
        ["read", "write", "edit", "multiedit"].each do |op|
          @formatters[op] = FileFormatterProxy.new(@file_formatter, op)
        end
        
        # Search operations (delegated to Search formatter)
        ["ls", "glob", "grep", "websearch"].each do |op|
          @formatters[op] = SearchFormatterProxy.new(@search_formatter, op)
        end
        
        # Web operations (delegated to Web formatter)
        ["webfetch"].each do |op|
          @formatters[op] = WebFormatterProxy.new(@web_formatter, op)
        end
        
        # Task management
        @formatters["task"] = Formatters::Task.new(@config)
        @formatters["todowrite"] = Formatters::Todo.new(@config)
      end
      
      def format_mcp_tool(tool_name, input)
        Formatters::Mcp.new(@config).format(tool_name, input)
      end
      
      def default_format(tool_name, input)
        "🔧 #{tool_name}(...)"
      end
      
      # Proxy classes to delegate to multi-tool formatters
      class FileFormatterProxy
        def initialize(formatter, operation)
          @formatter = formatter
          @operation = operation
        end
        
        def format(input)
          @formatter.format(@operation, input)
        end
      end
      
      class SearchFormatterProxy
        def initialize(formatter, operation)
          @formatter = formatter
          @operation = operation
        end
        
        def format(input)
          @formatter.format(@operation, input)
        end
      end
      
      class WebFormatterProxy
        def initialize(formatter, operation)
          @formatter = formatter
          @operation = operation
        end
        
        def format(input)
          @formatter.format(@operation, input)
        end
      end
    end
  end
end