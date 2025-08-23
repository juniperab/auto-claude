# frozen_string_literal: true

module AutoClaude
  module Output
    module Helpers
      class LinkParser
        def initialize(config = FormatterConfig.new)
          @config = config
        end

        def parse_links_line(line)
          return { lines: ["  #{line.chomp}"], has_more: false } unless line.match(/^Links:\s*\[(.*)\]/)

          links_json = ::Regexp.last_match(1)

          begin
            return { lines: ["  Links:"], has_more: false } if links_json.strip.empty?

            require "json"
            links = JSON.parse("[#{links_json}]")

            formatted = ["  Links:"]
            links.take(5).each do |link|
              formatted << format_link(link)
            end

            { lines: formatted, has_more: links.length > 5 }
          rescue StandardError
            { lines: ["  #{line.chomp}"], has_more: false }
          end
        end

        private

        def format_link(link)
          title = link["title"] || "Untitled"
          url = link["url"] || ""

          # Truncate title if needed
          if title.length > FormatterConfig::MAX_TITLE_LENGTH
            title = "#{title[0..(FormatterConfig::MAX_TITLE_LENGTH - 4)]}..."
          end

          domain = extract_domain(url)
          "    • #{title} (#{domain})"
        end

        def extract_domain(url)
          return "unknown" if url.nil? || url.empty?

          if url.match(%r{^https?://([^/]+)})
            domain = ::Regexp.last_match(1)
            domain.sub(/^www\./, "")
          else
            "unknown"
          end
        end
      end
    end
  end
end
