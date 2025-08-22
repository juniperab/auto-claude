require 'test_helper'
require 'auto_claude/output/formatters/web'
require 'auto_claude/output/formatter_config'

module AutoClaude
  module Output
    module Formatters
      class WebTest < Minitest::Test
        def setup
          @config = FormatterConfig.new
          @formatter = Web.new(@config)
        end
        
        # WebFetch operation tests
        def test_format_webfetch_basic
          input = { "url" => "https://example.com/page" }
          result = @formatter.format("webfetch", input)
          
          assert_equal "🌍 Fetching example.com", result
        end
        
        def test_format_webfetch_with_prompt
          input = {
            "url" => "https://example.com/page",
            "prompt" => "Extract all the links from this page"
          }
          result = @formatter.format("webfetch", input)
          
          assert_equal "🌍 Fetching example.com\n  analyzing: Extract all the links from this page...", result
        end
        
        def test_format_webfetch_with_long_prompt
          long_prompt = "This is a very long prompt " * 10
          input = {
            "url" => "https://example.com/page",
            "prompt" => long_prompt
          }
          result = @formatter.format("webfetch", input)
          
          expected_prompt = long_prompt[0..50] + "..."
          assert_equal "🌍 Fetching example.com\n  analyzing: #{expected_prompt}", result
        end
        
        def test_format_webfetch_empty_prompt
          input = {
            "url" => "https://example.com/page",
            "prompt" => ""
          }
          result = @formatter.format("webfetch", input)
          
          assert_equal "🌍 Fetching example.com", result
        end
        
        # WebSearch operation tests
        def test_format_websearch_basic
          input = { "query" => "ruby programming" }
          result = @formatter.format("websearch", input)
          
          assert_equal "🔍 Web searching: 'ruby programming'", result
        end
        
        def test_format_websearch_empty_query
          input = {}
          result = @formatter.format("websearch", input)
          
          assert_equal "🔍 Web searching: ''", result
        end
        
        # Unknown operation test
        def test_format_unknown_operation
          input = { "url" => "https://example.com" }
          result = @formatter.format("unknown_web", input)
          
          assert_equal "🌐 Web: unknown_web", result
        end
        
        # Domain extraction tests
        def test_extract_domain_https_url
          domain = @formatter.send(:extract_domain, "https://example.com/page")
          assert_equal "example.com", domain
        end
        
        def test_extract_domain_http_url
          domain = @formatter.send(:extract_domain, "http://example.com/page")
          assert_equal "example.com", domain
        end
        
        def test_extract_domain_with_www
          domain = @formatter.send(:extract_domain, "https://www.example.com/page")
          assert_equal "example.com", domain
        end
        
        def test_extract_domain_with_subdomain
          domain = @formatter.send(:extract_domain, "https://api.example.com/v1")
          assert_equal "api.example.com", domain
        end
        
        def test_extract_domain_with_port
          domain = @formatter.send(:extract_domain, "http://localhost:3000/test")
          assert_equal "localhost:3000", domain
        end
        
        def test_extract_domain_without_protocol
          domain = @formatter.send(:extract_domain, "example.com/page")
          assert_equal "example.com/page", domain
        end
        
        def test_extract_domain_nil
          domain = @formatter.send(:extract_domain, nil)
          assert_equal "unknown", domain
        end
        
        def test_extract_domain_empty
          domain = @formatter.send(:extract_domain, "")
          assert_equal "unknown", domain
        end
        
        def test_extract_domain_not_url
          domain = @formatter.send(:extract_domain, "not-a-url")
          assert_equal "not-a-url", domain
        end
        
        # Symbol key tests
        def test_format_with_symbol_keys
          input = { url: "https://example.com" }
          result = @formatter.format("webfetch", input)
          
          assert_equal "🌍 Fetching example.com", result
        end
        
        # Nil input tests
        def test_format_with_nil_input
          result = @formatter.format("webfetch", nil)
          
          assert_equal "🌍 Fetching unknown", result
        end
        
        def test_format_with_nil_url
          input = { "prompt" => "Analyze this" }
          result = @formatter.format("webfetch", input)
          
          assert_equal "🌍 Fetching unknown\n  analyzing: Analyze this...", result
        end
      end
    end
  end
end