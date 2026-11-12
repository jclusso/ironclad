# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'minitest/test_task'

Minitest::TestTask.create

require 'rubocop/rake_task'

RuboCop::RakeTask.new

task default: %i[test rubocop]

VERSION_FILE = 'lib/ironclad/version.rb'

namespace :release do
  desc 'Check, bump, commit, and tag a release, e.g. rake release:prepare[1.2.3]'
  task :prepare, [:version] do |_, args|
    version = args[:version].to_s
    tag = "v#{version}"
    abort 'error: version must be x.y.z' unless version.match?(/\A\d+\.\d+\.\d+\z/)
    abort 'error: working tree not clean' unless `git status --porcelain`.empty?
    abort 'error: release from master' unless `git branch --show-current`.strip == 'master'

    sh 'git fetch -q --tags origin master'
    unless `git rev-parse HEAD` == `git rev-parse origin/master`
      abort 'error: master is not in sync with origin'
    end

    current = Bundler::GemHelper.instance.gemspec.version
    unless Gem::Version.new(version) > current
      abort "error: version must be greater than #{current}"
    end
    abort "error: tag #{tag} already exists" unless `git tag -l #{tag}`.empty?

    Rake::Task[:test].invoke
    Rake::Task[:rubocop].invoke

    contents = File.read(VERSION_FILE)
    File.write(VERSION_FILE, contents.sub(/VERSION = '.*'/, "VERSION = '#{version}'"))
    # Gemfile.lock records the gem's own version, so it changes with the bump.
    sh 'bundle install --quiet'
    sh 'git', 'commit', '-q', '-m', tag, VERSION_FILE, 'Gemfile.lock'
    # Annotated, because `git push --follow-tags` skips lightweight tags.
    sh 'git', 'tag', '-a', tag, '-m', tag
    puts "Tagged #{tag}. Push the commit and tag to release: git push --follow-tags"
  end
end
