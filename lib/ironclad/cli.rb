# frozen_string_literal: true

require_relative '../ironclad'

module Ironclad
  # Command-line entry point. Dependency-free arg parsing keeps boot cheap and
  # avoids loading Rails just to print a key.
  #
  #   ironclad [env]               print the credentials key (default env)
  #   ironclad refresh [env]       re-cache one environment's key
  #   ironclad refresh --all       re-cache every environment's key
  #   ironclad edit [env]          edit Rails credentials for env
  #   ironclad diff <file>         git textconv: decrypt a credentials file
  class CLI
    def self.start(argv)
      new(argv).run
    end

    def initialize(argv)
      @argv = argv.dup
    end

    def run
      case @argv.first
      when 'refresh'
        @argv.shift
        return refresh
      when 'edit'
        @argv.shift
        edit(@argv.shift || 'default')
      when 'diff'
        @argv.shift
        diff(@argv.shift)
      when '-h', '--help', 'help'
        print_help
      else
        print_key
      end
      0
    rescue Error => e
      warn e.message
      1
    end

    private

    def print_key
      env = @argv.shift || 'default'
      validate_env!(env)
      puts Ironclad.key(env)
    end

    def refresh
      return refresh_all if @argv.delete('--all')

      env = @argv.shift || 'default'
      validate_env!(env)
      refresh_key(env) ? 0 : 1
    end

    def refresh_all
      environments = Ironclad.config.environments
      if environments.empty?
        raise Error, 'No environments are configured in config/ironclad.yml.'
      end

      failed = environments.reject { |env| refresh_key(env) }
      return 0 if failed.empty?

      warn "Failed to refresh: #{failed.join(', ')}."
      1
    end

    def refresh_key(env)
      Ironclad.key(env, refresh: true)
      puts "#{env}: refreshed"
      true
    rescue Error => e
      warn "#{env}: #{e.message}"
      false
    end

    def edit(env)
      validate_env!(env)
      ENV['RAILS_MASTER_KEY'] = Ironclad.key(env)
      Ironclad.configure_git_diff!

      args = ['credentials:edit']
      args.push('-e', env) unless env == 'default'
      exec('bin/rails', *args)
    end

    def diff(path)
      raise Error, 'Usage: ironclad diff <file>' unless path

      require_relative 'diff'
      Diff.call(path)
    end

    def validate_env!(env)
      return if Ironclad.config.environments.include?(env)

      raise Error, "Unknown environment: #{env} " \
                   "(expected #{Ironclad.config.environments.join(', ')})."
    end

    def print_help
      puts <<~HELP
        ironclad — Rails credential keys from 1Password, cached locally.

        Usage:
          ironclad [env]               print the credentials key (env: default)
          ironclad edit [env]          edit Rails credentials for env
          ironclad diff <file>         git textconv: decrypt a credentials file
          ironclad refresh [env]       re-cache one key (env: default)
          ironclad refresh --all       re-cache every environment's key
          ironclad --help              show this help

        refresh re-reads from the source after a key rotation.
        Environments are defined in config/ironclad.yml.
      HELP
    end
  end
end
