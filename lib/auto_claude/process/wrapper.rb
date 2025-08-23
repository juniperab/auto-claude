# frozen_string_literal: true

require "tempfile"
require "shellwords"

module AutoClaude
  module Process
    class Wrapper
      def initialize(directory)
        @directory = File.expand_path(directory)
        @script = nil
      end

      def create_script(command)
        @script = Tempfile.new(["claude_wrapper", ".sh"])
        @script.chmod(0o700)

        shell = determine_shell
        script_content = generate_script(shell, command)

        @script.write(script_content)
        @script.close

        @script.path
      end

      def cleanup
        return unless @script

        begin
          @script.unlink
        rescue StandardError
          nil
        end
        @script = nil
      end

      private

      def determine_shell
        user_shell = ENV["SHELL"] || ""
        shell_name = File.basename(user_shell).downcase

        # Check if we can use env
        if File.executable?("/usr/bin/env")
          env_prefix = "/usr/bin/env "

          # Prefer zsh if available
          if shell_name.include?("zsh")
            zsh_paths = %w[/usr/bin/zsh /bin/zsh /usr/local/bin/zsh]
            zsh_path = zsh_paths.find { |p| File.executable?(p) }
            return "#{env_prefix}zsh" if zsh_path
          end

          # Fall back to bash
          return "#{env_prefix}bash"
        end

        # Direct path fallback
        "/bin/bash"
      end

      def generate_script(shell, command)
        # Escape command arguments for shell
        escaped_command = command.map { |arg| Shellwords.escape(arg) }.join(" ")

        <<~SCRIPT
          #!#{shell}
          set -e

          # Change to the target directory
          cd "#{@directory}"

          # Clear environment that might interfere
          unset OLDPWD
          export PWD="#{@directory}"

          # Clear Ruby-specific environment that might interfere
          unset BUNDLE_GEMFILE
          unset RUBYLIB
          unset RUBYOPT

          # Execute claude with the provided arguments
          exec #{escaped_command}
        SCRIPT
      end
    end
  end
end
