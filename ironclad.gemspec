# frozen_string_literal: true

require_relative 'lib/ironclad/version'

Gem::Specification.new do |spec|
  spec.name = 'ironclad'
  spec.version = Ironclad::VERSION
  spec.authors = ['Jarrett Lusso']
  spec.email = ['jclusso@gmail.com']

  spec.homepage = 'https://github.com/jclusso/ironclad'
  spec.summary = '1Password-backed, OS-keystore-cached Rails credential keys.'
  spec.description = 'Ironclad sources Rails credential keys from 1Password ' \
                     'and caches them in the local OS keystore (macOS Keychain ' \
                     'or the Linux kernel keyring), so no key files live on ' \
                     'disk. Ships a CLI, a Railtie that loads the development ' \
                     'key at boot, Capistrano helpers, and an install generator.'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata = {
    'allowed_push_host' => 'https://rubygems.org',
    'homepage_uri' => spec.homepage,
    'source_code_uri' => spec.homepage,
    'documentation_uri' => spec.homepage,
    'changelog_uri' => "#{spec.homepage}/releases",
    'bug_tracker_uri' => "#{spec.homepage}/issues",
    'github_repo' => 'ssh://github.com/jclusso/ironclad',
    'rubygems_mfa_required' => 'true'
  }

  spec.files = Dir['lib/**/*', 'exe/*', 'LICENSE.txt', 'README.md']
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rubocop-cache-ventures'
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'minitest-reporters'
end
