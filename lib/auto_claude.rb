# frozen_string_literal: true

require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect("cli" => "CLI")
loader.setup

module AutoClaude
  # Convenience method for quick usage
  def self.run(prompt, **)
    client = Client.new(**)
    session = client.run(prompt)
    session.result&.content || ""
  end
end

loader.eager_load
