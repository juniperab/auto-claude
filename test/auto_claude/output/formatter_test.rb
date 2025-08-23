# frozen_string_literal: true

require "test_helper"
require "auto_claude/output/formatter"
require "auto_claude/messages/base"

module AutoClaude
  module Output
    class FormatterTest < Minitest::Test
      def setup
        @formatter = Formatter.new(color: false, truncate: false)
      end

      def test_format_write_tool
        msg = create_tool_message("Write", {
                                    "file_path" => "/src/main.rb",
                                    "content" => "puts 'hello world'"
                                  })

        output = @formatter.format_message(msg)

        assert_match(%r{✍️ Writing to /src/main.rb}, output)
        refute_match(/size:/, output) # Content is small
      end

      def test_format_write_tool_large_file
        msg = create_tool_message("Write", {
                                    "file_path" => "/src/large.rb",
                                    "content" => "x" * 2000
                                  })

        output = @formatter.format_message(msg)

        assert_match(%r{✍️ Writing to /src/large.rb}, output)
        assert_match(/size: 2\.0KB/, output)
      end

      def test_format_ls_tool
        msg = create_tool_message("LS", {
                                    "path" => "/Users/project"
                                  })

        output = @formatter.format_message(msg)

        assert_match(%r{📂 Listing /Users/project/}, output)
      end

      def test_format_ls_tool_with_ignore
        msg = create_tool_message("LS", {
                                    "path" => "/src",
                                    "ignore" => ["*.tmp", "*.log"]
                                  })

        output = @formatter.format_message(msg)

        assert_match(%r{📂 Listing /src/}, output)
        assert_match(/filter: excluding \["\*\.tmp", "\*\.log"\]/, output)
      end

      def test_format_grep_tool
        msg = create_tool_message("Grep", {
                                    "pattern" => "TODO",
                                    "path" => "/src"
                                  })

        output = @formatter.format_message(msg)

        assert_match(/🔍 Searching for 'TODO'/, output)
        assert_match(%r{in: /src}, output)
      end

      def test_format_grep_with_context
        msg = create_tool_message("Grep", {
                                    "pattern" => "error",
                                    "-C" => 3
                                  })

        output = @formatter.format_message(msg)

        assert_match(/🔍 Searching for 'error'/, output)
        assert_match(/context: ±3 lines/, output)
      end

      def test_format_bash_short_command
        msg = create_tool_message("Bash", {
                                    "command" => "ls -la"
                                  })

        output = @formatter.format_message(msg)

        assert_match(/🖥️ Running: ls -la/, output)
      end

      def test_format_bash_long_command_with_description
        msg = create_tool_message("Bash", {
                                    "command" => "find . -type f -name '*.rb' | xargs grep -l TODO | head -20",
                                    "description" => "Find files with TODOs"
                                  })

        output = @formatter.format_message(msg)

        assert_match(/🖥️ Executing: Find files with TODOs/, output)
        refute_match(/find \. -type/, output) # Long command not shown
      end

      def test_format_mcp_search_tool
        msg = create_tool_message("mcp__code-server__search_code", {
                                    "query" => "authentication flow"
                                  })

        output = @formatter.format_message(msg)

        assert_match(/🔍 Search Code: 'authentication flow'/, output)
        assert_match(/server: code-server/, output)
      end

      def test_format_mcp_github_tool
        msg = create_tool_message("mcp__git-service__get_issue", {
                                    "owner" => "acme-corp",
                                    "repo" => "main-app",
                                    "issue_number" => 123
                                  })

        output = @formatter.format_message(msg)

        assert_match(%r{📥 Get Issue: acme-corp/main-app#123}, output)
        assert_match(/server: git-service/, output)
      end

      def test_format_mcp_create_operation
        msg = create_tool_message("mcp__project-manager__create_project", {
                                    "name" => "new-feature"
                                  })

        output = @formatter.format_message(msg)

        assert_match(/✨ Create Project: new-feature/, output)
        assert_match(/server: project-manager/, output)
      end

      def test_format_mcp_delete_operation
        msg = create_tool_message("mcp__file-service__delete_file", {
                                    "file_id" => "abc123"
                                  })

        output = @formatter.format_message(msg)

        assert_match(/🗑️ Delete File: abc123/, output)
        assert_match(/server: file-service/, output)
      end

      def test_format_todo_write_with_all_states
        msg = create_tool_message("TodoWrite", {
                                    "todos" => [
                                      { "content" => "Setup database", "status" => "completed" },
                                      { "content" => "Create models", "status" => "completed" },
                                      { "content" => "Write controllers", "status" => "in_progress" },
                                      { "content" => "Add tests", "status" => "pending" },
                                      { "content" => "Deploy", "status" => "pending" }
                                    ]
                                  })

        output = @formatter.format_message(msg)
        lines = output.split("\n")

        assert_match(/📝 Todo: updating task list/, lines[0])
        # Shows last 2 completed (Setup database, Create models)
        assert_match(/        \[x\] Setup database/, lines[1])
        assert_match(/        \[x\] Create models/, lines[2])
        # Shows the in_progress
        assert_match(/        \[-\] Write controllers/, lines[3])
        # Shows first 2 pending
        assert_match(/        \[ \] Add tests/, lines[4])
        assert_match(/        \[ \] Deploy/, lines[5])
      end

      def test_format_todo_write_many_tasks
        todos = []
        10.times { |i| todos << { "content" => "Task #{i}", "status" => "completed" } }
        2.times { |i| todos << { "content" => "Current #{i}", "status" => "in_progress" } }
        15.times { |i| todos << { "content" => "Future #{i}", "status" => "pending" } }

        msg = create_tool_message("TodoWrite", {
                                    "todos" => todos
                                  })

        output = @formatter.format_message(msg)
        lines = output.split("\n")

        assert_match(/📝 Todo: 27 tasks \(10 completed\)/, lines[0])
        assert_equal 6, lines.length # Summary + 5 items (now shows 5 instead of 3)
      end

      def test_format_web_fetch
        msg = create_tool_message("WebFetch", {
                                    "url" => "https://docs.ruby-lang.org/en/3.0/String.html",
                                    "prompt" => "Extract string methods"
                                  })

        output = @formatter.format_message(msg)

        assert_match(/🌍 Fetching docs.ruby-lang.org/, output)
        assert_match(/analyzing: Extract string methods/, output)
      end

      def test_format_web_search
        msg = create_tool_message("WebSearch", {
                                    "query" => "Ruby on Rails best practices"
                                  })

        output = @formatter.format_message(msg)

        assert_match(/🔍 Web searching: 'Ruby on Rails best practices'/, output)
      end

      def test_format_multi_edit
        msg = create_tool_message("MultiEdit", {
                                    "file_path" => "/src/controller.rb",
                                    "edits" => [
                                      { "old_string" => "foo", "new_string" => "bar" },
                                      { "old_string" => "baz", "new_string" => "qux" },
                                      { "old_string" => "hello", "new_string" => "world" }
                                    ]
                                  })

        output = @formatter.format_message(msg)

        assert_match(%r{✂️ Bulk editing /src/controller.rb}, output)
        assert_match(/changes: 3 edits/, output)
      end

      def test_format_glob
        msg = create_tool_message("Glob", {
                                    "pattern" => "**/*.rb"
                                  })

        output = @formatter.format_message(msg)

        assert_match(%r{🎯 Searching for \*\*/\*\.rb}, output)
      end

      def test_format_task_delegation
        msg = create_tool_message("Task", {
                                    "description" => "search for auth patterns",
                                    "subagent_type" => "general-purpose"
                                  })

        output = @formatter.format_message(msg)

        assert_match(/🤖 Delegating: search for auth patterns/, output)
        assert_match(/agent: general-purpose/, output)
      end

      def test_format_unknown_tool
        msg = create_tool_message("SomeRandomTool", {
                                    "param" => "value"
                                  })

        output = @formatter.format_message(msg)

        assert_match(/🔧 SomeRandomTool\(/, output)
      end

      def test_format_tool_result_success
        msg = create_tool_result({
                                   "output" => "Command completed successfully",
                                   "is_error" => false
                                 })

        output = @formatter.format_message(msg)

        assert_match(/   Result: Command completed successfully/, output)
      end

      def test_format_tool_result_error
        msg = create_tool_result({
                                   "output" => "Permission denied",
                                   "is_error" => true
                                 })

        output = @formatter.format_message(msg)

        assert_match(/⚠️ Error: Permission denied/, output)
      end

      def test_format_tool_result_large
        msg = create_tool_result({
                                   "output" => "x" * 1000,
                                   "is_error" => false
                                 })

        output = @formatter.format_message(msg)
        lines = output.split("\n")

        assert_match(/   Result: \[1 lines, 1\.0KB\]/, lines[0])
        assert_match(/^        x+$/, lines[1])
        assert_equal 2, lines.length # Single line, no ellipsis
      end

      def test_format_text_message
        json = {
          "type" => "assistant",
          "message" => {
            "content" => [
              { "type" => "text", "text" => "I'll help you with that." }
            ]
          }
        }

        msg = Messages::Base.from_json(json)
        output = @formatter.format_message(msg)

        assert_match(/💭 I'll help you with that\./, output)
      end

      def test_format_user_prompt
        output = @formatter.format_user_prompt("Fix the bug in authentication")

        assert_match(/👤 User: Fix the bug in authentication/, output)
      end

      def test_format_session_start
        output = @formatter.format_session_start("/Users/project")

        assert_match(%r{🚀 Session: starting in /Users/project}, output)
      end

      def test_format_session_complete
        output = @formatter.format_session_complete(5, 2.3, 0.0025)

        assert_match(/✅ Complete: 5 tasks, 2.3s, \$0.002500/, output)
      end

      def test_format_stats
        output = @formatter.format_stats(150, 75)

        assert_match(/📊 Stats: 150↑ 75↓ tokens/, output)
      end

      private

      def create_tool_message(tool_name, input)
        json = {
          "type" => "tool_use",
          "id" => "toolu_test123",
          "name" => tool_name,
          "input" => input
        }
        Messages::Base.from_json(json)
      end

      def create_tool_result(content)
        json = {
          "type" => "user",
          "message" => {
            "content" => [
              {
                "type" => "tool_result",
                "tool_use_id" => "toolu_test123",
                "content" => content["output"],
                "is_error" => content["is_error"] || false
              }
            ]
          }
        }
        Messages::Base.from_json(json)
      end
    end
  end
end
