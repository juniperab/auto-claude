require 'test_helper'
require 'auto_claude/output/formatters/mcp'
require 'auto_claude/output/formatter_config'

module AutoClaude
  module Output
    module Formatters
      class McpTest < Minitest::Test
        def setup
          @config = FormatterConfig.new
          @formatter = Mcp.new(@config)
        end
        
        def test_format_basic
          tool_name = "mcp__vault__search"
          input = { "query" => "ruby programming" }
          result = @formatter.format(tool_name, input)
          
          assert_equal "🔍 Search: 'ruby programming'\n        server: vault", result
        end
        
        def test_format_with_unknown_server
          tool_name = "mcp____action"
          input = {}
          result = @formatter.format(tool_name, input)
          
          assert_equal "🔧 Action: \n        server: ", result
        end
        
        def test_format_search_operation
          tool_name = "mcp__github__search_repos"
          input = { "query" => "shopify" }
          result = @formatter.format(tool_name, input)
          
          assert_equal "🔍 Search Repos: 'shopify'\n        server: github", result
        end
        
        def test_format_get_operation
          tool_name = "mcp__vault__get_user"
          input = { "user_id" => "123" }
          result = @formatter.format(tool_name, input)
          
          assert_equal "📥 Get User: 123\n        server: vault", result
        end
        
        def test_format_list_operation
          tool_name = "mcp__github__list_issues"
          input = { "repo" => "shopify/shopify" }
          result = @formatter.format(tool_name, input)
          
          assert_equal "📃 List Issues: shopify/shopify\n        server: github", result
        end
        
        def test_format_create_operation
          tool_name = "mcp__vault__create_page"
          input = { "title" => "New Page" }
          result = @formatter.format(tool_name, input)
          
          assert_equal "✨ Create Page: New Page\n        server: vault", result
        end
        
        def test_format_delete_operation
          tool_name = "mcp__github__delete_branch"
          input = { "branch" => "feature-x" }
          result = @formatter.format(tool_name, input)
          
          assert_equal "🗑️ Delete Branch: feature-x\n        server: github", result
        end
        
        def test_format_update_operation
          tool_name = "mcp__vault__update_post"
          input = { "post_id" => "456" }
          result = @formatter.format(tool_name, input)
          
          assert_equal "✏️ Update Post: 456\n        server: vault", result
        end
        
        def test_format_send_operation
          tool_name = "mcp__slack__send_message"
          input = { "message" => "Hello" }
          result = @formatter.format(tool_name, input)
          
          assert_equal "📤 Send Message: Hello\n        server: slack", result
        end
        
        def test_format_github_issue_reference
          tool_name = "mcp__github__get_issue"
          input = {
            "owner" => "shopify",
            "repo" => "shopify",
            "issue_number" => 123
          }
          result = @formatter.format(tool_name, input)
          
          assert_equal "📥 Get Issue: shopify/shopify#123\n        server: github", result
        end
        
        def test_format_github_pr_reference
          tool_name = "mcp__github__get_pr"
          input = {
            "owner" => "shopify",
            "repo" => "shopify",
            "pull_number" => 456
          }
          result = @formatter.format(tool_name, input)
          
          assert_equal "📥 Get Pr: shopify/shopify#456\n        server: github", result
        end
        
        def test_format_github_repo_reference
          tool_name = "mcp__github__get_repo"
          input = {
            "owner" => "shopify",
            "repo" => "shopify"
          }
          result = @formatter.format(tool_name, input)
          
          assert_equal "📥 Get Repo: shopify/shopify\n        server: github", result
        end
        
        def test_format_empty_input
          tool_name = "mcp__vault__get_something"
          input = {}
          result = @formatter.format(tool_name, input)
          
          assert_equal "📥 Get Something: \n        server: vault", result
        end
        
        def test_format_nil_input
          tool_name = "mcp__vault__search"
          input = nil
          result = @formatter.format(tool_name, input)
          
          assert_equal "🔍 Search: \n        server: vault", result
        end
        
        def test_format_single_key_input
          tool_name = "mcp__vault__fetch"
          input = { "id" => "789" }
          result = @formatter.format(tool_name, input)
          
          assert_equal "📥 Fetch: 789\n        server: vault", result
        end
        
        def test_humanize_action
          assert_equal "Get User", @formatter.send(:humanize_action, "get_user")
          assert_equal "Search Repos", @formatter.send(:humanize_action, "search_repos")
          assert_equal "Create New Item", @formatter.send(:humanize_action, "create_new_item")
          assert_equal "Unknown", @formatter.send(:humanize_action, nil)
        end
        
        def test_select_emoji_for_various_actions
          assert_equal "🔍", @formatter.send(:select_emoji, "search_users")
          assert_equal "🔍", @formatter.send(:select_emoji, "find_items")
          assert_equal "📥", @formatter.send(:select_emoji, "get_data")
          assert_equal "📥", @formatter.send(:select_emoji, "fetch_info")
          assert_equal "📥", @formatter.send(:select_emoji, "read_file")
          assert_equal "📃", @formatter.send(:select_emoji, "list_all")
          assert_equal "📃", @formatter.send(:select_emoji, "index_items")
          assert_equal "✨", @formatter.send(:select_emoji, "create_new")
          assert_equal "✨", @formatter.send(:select_emoji, "add_item")
          assert_equal "🗑️", @formatter.send(:select_emoji, "delete_item")
          assert_equal "🗑️", @formatter.send(:select_emoji, "remove_all")
          assert_equal "✏️", @formatter.send(:select_emoji, "update_data")
          assert_equal "✏️", @formatter.send(:select_emoji, "edit_file")
          assert_equal "✏️", @formatter.send(:select_emoji, "modify_config")
          assert_equal "📤", @formatter.send(:select_emoji, "send_email")
          assert_equal "📤", @formatter.send(:select_emoji, "post_message")
          assert_equal "📤", @formatter.send(:select_emoji, "submit_form")
          assert_equal "🔧", @formatter.send(:select_emoji, "unknown_action")
        end
        
        def test_format_with_symbol_keys
          tool_name = "mcp__vault__search"
          input = { query: "test" }
          result = @formatter.format(tool_name, input)
          
          assert_equal "🔍 Search: 'test'\n        server: vault", result
        end
      end
    end
  end
end