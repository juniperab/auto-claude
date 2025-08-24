# frozen_string_literal: true

require_relative "integration_helper"
require "tmpdir"
require "fileutils"

module AutoClaude
  module IntegrationTest
    class WorkingDirectoryTest < Base
      def test_claude_respects_working_directory_cli
        Dir.mktmpdir do |tmpdir|
          # Create a test file in the temp directory
          test_file = File.join(tmpdir, "test_file.txt")
          File.write(test_file, "Hello from test file!")

          # Create a subdirectory with another file
          subdir = File.join(tmpdir, "subdir")
          FileUtils.mkdir_p(subdir)
          File.write(File.join(subdir, "nested.txt"), "Nested content")

          # Run auto-claude from the temp directory
          result = run_auto_claude_cli(
            "List the files in the current directory using ls, then cat test_file.txt",
            working_directory: tmpdir
          )

          skip "Claude CLI failed: #{result[:stderr]}" unless result[:success]

          # Claude should see the files in tmpdir
          assert_match(/test_file\.txt/, result[:stdout],
                       "Claude should list test_file.txt in the working directory")
          assert_match(/subdir/, result[:stdout],
                       "Claude should list the subdir directory")
          assert_match(/Hello from test file/, result[:stdout],
                       "Claude should be able to read the test file")
        end
      end

      def test_claude_respects_working_directory_api
        Dir.mktmpdir do |tmpdir|
          # Create test files
          File.write(File.join(tmpdir, "api_test.txt"), "API test content")

          # Run via API with custom directory
          result = run_auto_claude_api(
            "Run pwd command and list files with ls",
            directory: tmpdir
          )

          skip "API call failed: #{result[:error]&.message}" unless result[:success]

          # Claude should be working in the tmpdir
          assert_match(/api_test\.txt/, result[:result],
                       "Claude should see api_test.txt in the working directory")
        end
      end

      def test_working_directory_isolation
        Dir.mktmpdir do |tmpdir1|
          Dir.mktmpdir do |tmpdir2|
            # Create different files in each directory
            File.write(File.join(tmpdir1, "file1.txt"), "Directory 1")
            File.write(File.join(tmpdir2, "file2.txt"), "Directory 2")

            # Run Claude in first directory
            result1 = run_auto_claude_cli(
              "List files with ls",
              working_directory: tmpdir1
            )

            # Run Claude in second directory
            result2 = run_auto_claude_cli(
              "List files with ls",
              working_directory: tmpdir2
            )

            skip "Claude CLI failed" unless result1[:success] && result2[:success]

            # First run should only see file1.txt
            assert_match(/file1\.txt/, result1[:stdout],
                         "First run should see file1.txt")
            refute_match(/file2\.txt/, result1[:stdout],
                         "First run should NOT see file2.txt")

            # Second run should only see file2.txt
            assert_match(/file2\.txt/, result2[:stdout],
                         "Second run should see file2.txt")
            refute_match(/file1\.txt/, result2[:stdout],
                         "Second run should NOT see file1.txt")
          end
        end
      end

      def test_pwd_command_shows_correct_directory
        Dir.mktmpdir do |tmpdir|
          result = run_auto_claude_cli(
            "Run the pwd command and show the output",
            working_directory: tmpdir
          )

          skip "Claude CLI failed: #{result[:stderr]}" unless result[:success]

          # The output should contain the tmpdir path
          # Note: macOS might add /private prefix
          assert(result[:stdout].include?(tmpdir) ||
                 result[:stdout].include?("/private#{tmpdir}"),
                 "PWD output should show the working directory: #{tmpdir}")

          if ENV["DEBUG"]
            puts "\n=== PWD Test Output ==="
            puts "Working directory: #{tmpdir}"
            puts "Claude output:"
            puts result[:stdout]
            puts "====================="
          end
        end
      end
    end
  end
end
