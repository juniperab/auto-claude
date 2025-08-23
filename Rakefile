# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.verbose = true
end

begin
  require "rubocop/rake_task"
  RuboCop::RakeTask.new
rescue LoadError
  puts "RuboCop not available, skipping rubocop task"
end

task default: %i[test rubocop]
