# frozen_string_literal: true

require "rake/testtask"

# Regular unit tests (excludes integration tests)
Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"].exclude("test/integration/**/*")
  t.verbose = true
end

namespace :test do
  desc "Run integration tests with real Claude CLI"
  task :integration do
    ENV["INTEGRATION"] = "true"
    Rake::TestTask.new(:integration_runner) do |t|
      t.libs << "test"
      t.libs << "lib"
      t.test_files = FileList["test/integration/**/*_test.rb"]
      t.verbose = true
    end
    Rake::Task[:integration_runner].invoke
  end

  desc "Run all tests including integration"
  task all: %i[test integration]
end

begin
  require "rubocop/rake_task"
  RuboCop::RakeTask.new
rescue LoadError
  puts "RuboCop not available, skipping rubocop task"
end

task default: %i[test rubocop]
