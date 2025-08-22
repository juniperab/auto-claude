require 'test_helper'
require 'auto_claude/output/formatters/task'
require 'auto_claude/output/formatter_config'

module AutoClaude
  module Output
    module Formatters
      class TaskTest < Minitest::Test
        def setup
          @config = FormatterConfig.new
          @formatter = Task.new(@config)
        end
        
        def test_format_basic
          input = {
            "description" => "Search for files",
            "subagent_type" => "search"
          }
          result = @formatter.format(input)
          
          assert_equal "🤖 Delegating: Search for files\n  agent: search", result
        end
        
        def test_format_with_default_description
          input = { "subagent_type" => "general" }
          result = @formatter.format(input)
          
          assert_equal "🤖 Delegating: task\n  agent: general", result
        end
        
        def test_format_with_default_agent
          input = { "description" => "Process data" }
          result = @formatter.format(input)
          
          assert_equal "🤖 Delegating: Process data\n  agent: general", result
        end
        
        def test_format_with_all_defaults
          input = {}
          result = @formatter.format(input)
          
          assert_equal "🤖 Delegating: task\n  agent: general", result
        end
        
        def test_format_with_symbol_keys
          input = {
            description: "Run tests",
            subagent_type: "test-runner"
          }
          result = @formatter.format(input)
          
          assert_equal "🤖 Delegating: Run tests\n  agent: test-runner", result
        end
        
        def test_format_with_nil_input
          result = @formatter.format(nil)
          
          assert_equal "🤖 Delegating: task\n  agent: general", result
        end
        
        def test_format_various_agent_types
          agents = ["general", "search", "code-reviewer", "test-runner", "documentation"]
          
          agents.each do |agent|
            input = {
              "description" => "Test task",
              "subagent_type" => agent
            }
            result = @formatter.format(input)
            
            assert_equal "🤖 Delegating: Test task\n  agent: #{agent}", result
          end
        end
      end
    end
  end
end