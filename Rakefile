# frozen_string_literal: true

require "rake/testtask"

# Regular unit tests (excludes integration tests)
Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"].exclude("test/integration/**/*")
  t.verbose = true
end

# Integration tests that use real Claude CLI
Rake::TestTask.new(:integration) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/integration/**/*_test.rb"]
  t.verbose = true
  t.description = "Run integration tests with real Claude CLI (requires INTEGRATION=true)"
end

namespace :test do
  desc "Run all tests including integration (requires INTEGRATION=true for integration tests)"
  task all: %i[test integration]

  desc "Run only integration tests with real Claude CLI"
  task :integration_only do
    ENV["INTEGRATION"] = "true"
    Rake::Task[:integration].invoke
  end
end

begin
  require "rubocop/rake_task"
  RuboCop::RakeTask.new
rescue LoadError
  puts "RuboCop not available, skipping rubocop task"
end

task default: %i[test rubocop]
