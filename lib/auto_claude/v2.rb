# Main entry point for V2 implementation
require_relative 'v2/client'
require_relative 'v2/session'
require_relative 'v2/cli'
require_relative 'v2/messages/base'
require_relative 'v2/output/writer'
require_relative 'v2/output/terminal'
require_relative 'v2/output/memory'
require_relative 'v2/output/file'

module AutoClaude
  module V2
    VERSION = "2.0.0"
    
    # Convenience method for quick usage
    def self.run(prompt, **options)
      client = Client.new(**options)
      session = client.run(prompt)
      session.result&.content || ""
    end
  end
end