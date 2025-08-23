# frozen_string_literal: true

module AutoClaude
  module Output
    module Formatters
      class Mcp < Base
        def format(tool_name, input)
          parts = tool_name.split("__")
          server = parts[1] || "unknown"
          action = parts[2] || parts.last || "action"

          emoji = select_emoji(action)
          primary_arg = extract_primary_arg(action, input)
          indent = " " * FormatterConfig::STANDARD_INDENT

          "#{emoji} #{humanize_action(action)}: #{primary_arg}\n#{indent}server: #{server}"
        end

        private

        def select_emoji(action)
          action_lower = action.downcase

          if action_lower.include?("search") || action_lower.include?("find")
            FormatterConfig::TOOL_EMOJIS[:mcp_search]
          elsif action_lower.include?("get") || action_lower.include?("fetch") || action_lower.include?("read")
            FormatterConfig::TOOL_EMOJIS[:mcp_get]
          elsif action_lower.include?("list") || action_lower.include?("index")
            FormatterConfig::TOOL_EMOJIS[:mcp_list]
          elsif action_lower.include?("create") || action_lower.include?("add") || action_lower.include?("new")
            FormatterConfig::TOOL_EMOJIS[:mcp_create]
          elsif action_lower.include?("delete") || action_lower.include?("remove")
            FormatterConfig::TOOL_EMOJIS[:mcp_delete]
          elsif action_lower.include?("update") || action_lower.include?("edit") || action_lower.include?("modify")
            FormatterConfig::TOOL_EMOJIS[:mcp_update]
          elsif action_lower.include?("send") || action_lower.include?("post") || action_lower.include?("submit")
            FormatterConfig::TOOL_EMOJIS[:mcp_send]
          else
            FormatterConfig::TOOL_EMOJIS[:mcp_default]
          end
        end

        def extract_primary_arg(_action, input)
          return "" unless input.is_a?(Hash)

          # Try common patterns
          if (query = extract_value(input, "query"))
            "'#{query}'"
          elsif (repo = extract_value(input, "repo")) && (owner = extract_value(input, "owner"))
            format_github_reference(input, repo, owner)
          elsif input.keys.length == 1
            input.values.first.to_s
          elsif input.keys.any?
            "#{input.keys.first}: #{input.values.first}"
          else
            ""
          end
        end

        def format_github_reference(input, repo, owner)
          issue_num = extract_value(input, "issue_number")
          pr_num = extract_value(input, "pull_number")
          num = issue_num || pr_num

          num ? "#{owner}/#{repo}##{num}" : "#{owner}/#{repo}"
        end

        def humanize_action(action)
          return "Unknown" unless action

          action.to_s.gsub("_", " ").split.map(&:capitalize).join(" ")
        end
      end
    end
  end
end
