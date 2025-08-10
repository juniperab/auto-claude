require 'json'
require 'time'

module AutoClaude
    module Messages
      class Base
        attr_reader :type, :timestamp, :raw_json

        def initialize(json)
          @raw_json = json
          @type = json["type"]
          @timestamp = Time.now
          parse_json(json)
        end

        def self.from_json(json)
          return nil unless json.is_a?(Hash)
          
          case json["type"]
          when "assistant"
            parse_assistant_message(json)
          when "user"
            parse_user_message(json)
          when "tool_use"
            # Direct tool_use message (not nested in assistant message)
            ToolUseMessage.new(json)
          when "result"
            ResultMessage.new(json)
          when "system"
            SystemMessage.new(json)
          else
            UnknownMessage.new(json)
          end
        end

        def to_h
          @raw_json
        end

        protected

        def parse_json(json)
          # Override in subclasses
        end

        private

        def self.parse_assistant_message(json)
          content = json.dig("message", "content")
          return UnknownMessage.new(json) unless content.is_a?(Array)
          
          # Assistant messages can have multiple content items
          content_item = content.first || {}
          
          case content_item["type"]
          when "text"
            TextMessage.new(json)
          when "tool_use"
            ToolUseMessage.new(json)
          else
            UnknownMessage.new(json)
          end
        end

        def self.parse_user_message(json)
          content = json.dig("message", "content")
          return UnknownMessage.new(json) unless content.is_a?(Array)
          
          content_item = content.first || {}
          
          case content_item["type"]
          when "tool_result"
            ToolResultMessage.new(json)
          when "text"
            TextMessage.new(json)
          else
            UnknownMessage.new(json)
          end
        end
      end

      class TextMessage < Base
        attr_reader :text, :role

        protected

        def parse_json(json)
          @role = json["type"] # "assistant" or "user"
          content = json.dig("message", "content")
          
          if content.is_a?(Array)
            text_content = content.find { |c| c["type"] == "text" }
            @text = text_content["text"] if text_content
          elsif content.is_a?(String)
            @text = content
          else
            @text = ""
          end
        end
      end

      class ToolUseMessage < Base
        attr_reader :tool_name, :tool_input, :tool_id

        protected

        def parse_json(json)
          # Handle both nested and direct tool_use messages
          if json["type"] == "tool_use"
            # Direct tool_use message (from unhandled messages)
            @tool_id = json["id"]
            @tool_name = json["name"]
            @tool_input = json["input"] || {}
          else
            # Nested in assistant message content
            content = json.dig("message", "content")
            
            if content.is_a?(Array)
              tool_content = content.find { |c| c["type"] == "tool_use" }
              if tool_content
                @tool_id = tool_content["id"]
                @tool_name = tool_content["name"]
                @tool_input = tool_content["input"] || {}
              end
            end
          end
          
          @tool_id ||= ""
          @tool_name ||= "Unknown"
          @tool_input ||= {}
        end
      end

      class ToolResultMessage < Base
        attr_reader :tool_name, :output, :is_error

        protected

        def parse_json(json)
          content = json.dig("message", "content")
          
          if content.is_a?(Array)
            result_content = content.find { |c| c["type"] == "tool_result" }
            if result_content
              @tool_name = result_content["tool_use_id"] || "Unknown"
              @output = result_content["content"] || ""
              @is_error = result_content["is_error"] || false
            end
          end
          
          @tool_name ||= "Unknown"
          @output ||= ""
          @is_error ||= false
        end
      end

      class ResultMessage < Base
        attr_reader :content, :success, :error_message, :metadata

        def success?
          @success
        end

        def error?
          !@success
        end

        protected

        def parse_json(json)
          @content = json["result"] || ""
          @success = json["subtype"] == "success" || json["success"] == true
          
          if json["is_error"] || json["subtype"] == "error"
            @success = false
            @error_message = json["result"] || json.dig("error", "message") || "Unknown error"
          end
          
          # Extract metadata
          @metadata = {
            "success" => @success,
            "num_turns" => json["num_turns"],
            "duration_ms" => json["duration_ms"],
            "total_cost_usd" => json["total_cost_usd"],
            "usage" => json["usage"] || {},
            "session_id" => json["session_id"],
            "error_message" => @error_message
          }.compact
        end
      end

      class SystemMessage < Base
        attr_reader :message

        protected

        def parse_json(json)
          @message = json["message"] || ""
        end
      end

      class UnknownMessage < Base
        protected

        def parse_json(json)
          # Keep raw json accessible
        end
      end
  end
end