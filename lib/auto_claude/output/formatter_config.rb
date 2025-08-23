# frozen_string_literal: true

module AutoClaude
  module Output
    class FormatterConfig
      # Display limits
      MAX_LINE_LENGTH = 100
      MAX_PREVIEW_LINES = 5
      MAX_TODO_DISPLAY = 6
      MAX_TITLE_LENGTH = 50

      # Formatting
      STANDARD_INDENT = 8 # Standard indentation for preview content

      # Sizes
      KB_SIZE = 1024
      LONG_COMMAND_THRESHOLD = 50

      # Messages to filter out
      FILTERED_MESSAGE_PREFIXES = [
        "Todos have been modified successfully",
        "Todo list has been updated",
        "Tasks have been updated"
      ].freeze

      # Tool emojis
      TOOL_EMOJIS = {
        # File operations
        read: "👀",
        write: "✍️",
        edit: "✏️",
        multiedit: "✂️",

        # Search operations
        ls: "📂",
        glob: "🎯",
        grep: "🔍",
        websearch: "🔍",

        # Execution
        bash: "🖥️",

        # Web
        webfetch: "🌍",

        # Task management
        task: "🤖",
        todowrite: "📝",

        # MCP defaults
        mcp_search: "🔍",
        mcp_get: "📥",
        mcp_list: "📃",
        mcp_create: "✨",
        mcp_delete: "🗑️",
        mcp_update: "✏️",
        mcp_send: "📤",
        mcp_default: "🔧"
      }.freeze

      # Status icons for todos
      TODO_STATUS_ICONS = {
        "completed" => "[x]",
        "in_progress" => "[-]",
        "pending" => "[ ]"
      }.freeze

      # Message type emojis
      MESSAGE_EMOJIS = {
        user: "👤",
        assistant: "💭",
        error: "⚠️",
        result: "  ",
        session_start: "🚀",
        session_complete: "✅",
        stats: "📊"
      }.freeze

      attr_reader :color, :truncate, :max_lines

      def initialize(color: true, truncate: true, max_lines: MAX_PREVIEW_LINES)
        @color = color
        @truncate = truncate
        @max_lines = max_lines
      end
    end
  end
end
