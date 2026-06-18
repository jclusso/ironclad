# frozen_string_literal: true

require_relative '../ironclad'

module Ironclad
  # Command-line entry point. Dependency-free arg parsing keeps boot cheap and
  # avoids loading Rails just to print a key.
  #
  #   ironclad [env] [--refresh]   print the credentials key (default env)
  #   ironclad edit [env]          edit Rails credentials for env
  class CLI
    def self.start(argv)
      new(argv).run
    end

    def initialize(argv)
      @argv = argv.dup
    end

    def run
      case @argv.first
      when 'edit'
        @argv.shift
        edit(@argv.shift || 'default')
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
      refresh = @argv.delete('--refresh') ? true : false
      env = @argv.shift || 'default'
      validate_env!(env)
      puts Ironclad.key(env, refresh: refresh)
    end

    def edit(env)
      validate_env!(env)
      ENV['RAILS_MASTER_KEY'] = Ironclad.key(env)

      args = ['credentials:edit']
      args.push('-e', env) unless env == 'default'
      exec('bin/rails', *args)
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
          ironclad [env] [--refresh]   print the credentials key (env: default)
          ironclad edit [env]          edit Rails credentials for env
          ironclad --help              show this help

        --refresh re-reads from the source after a key rotation.
        Environments are defined in config/ironclad.yml.
      HELP
    end
  end
end
