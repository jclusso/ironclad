# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'minitest/test_task'

Minitest::TestTask.create

require 'rubocop/rake_task'

RuboCop::RakeTask.new

task default: %i[test rubocop]

VERSION_FILE = 'lib/ironclad/version.rb'

desc 'Bump VERSION, update Gemfile.lock, commit, and tag (then: git push --follow-tags)'
task :bump do
  version = ENV['VERSION']
  abort 'Usage: rake bump VERSION=1.2.3' unless version
  abort "Invalid version: #{version}" unless version.match?(/\A\d+\.\d+\.\d+\z/)
  abort 'Working tree is dirty. Commit or stash first.' unless `git status --porcelain`.strip.empty?

  contents = File.read(VERSION_FILE)
  updated = contents.sub(/VERSION = '[^']*'/, "VERSION = '#{version}'")
  abort "Could not find VERSION in #{VERSION_FILE}" if updated == contents
  File.write(VERSION_FILE, updated)

  sh 'bundle install'
  sh 'git', 'add', VERSION_FILE, 'Gemfile.lock'
  sh 'git', 'commit', '-m', "v#{version}"
  sh 'git', 'tag', "v#{version}"

  puts "\nTagged v#{version}. Push with:\n  git push --follow-tags"
end
