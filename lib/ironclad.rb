# frozen_string_literal: true

require_relative 'ironclad/version'
require_relative 'ironclad/config'
require_relative 'ironclad/source'
require_relative 'ironclad/source/one_password'
require_relative 'ironclad/cache'
require_relative 'ironclad/key_store'

# Sources Rails credential keys from a secrets manager, cached in the local OS
# keystore.
module Ironclad
  class Error < StandardError; end

  # Raised when an explicit refresh fetched the key but could not cache it. The
  # key is still valid, so callers can report the failure and use it anyway.
  class CacheWriteError < Error
    attr_reader :key

    def initialize(message, key)
      super(message)
      @key = key
    end
  end

  GIT_DIFF_DRIVER = 'rails_credentials'
  DIFF_COMMAND = 'bin/ironclad diff'

  class << self
    # Path to the project's ironclad.yml. Override before first use if needed.
    attr_writer :config_path

    def config_path
      @config_path ||= File.join(Dir.pwd, 'config', 'ironclad.yml')
    end

    def configured?
      File.exist?(config_path)
    end

    def config
      @config ||= Config.load(config_path)
    end

    def store
      @store ||= KeyStore.new(config)
    end

    # Return the credentials key for an environment, using the read-through
    # cache. Pass refresh: true to bypass the cache after a key rotation.
    def key(environment = 'default', refresh: false)
      store.key(environment.to_s, refresh: refresh)
    end

    def configure_git_diff!(command = DIFF_COMMAND)
      return unless enrolled_in_git_diff?

      system('git', 'config', "diff.#{GIT_DIFF_DRIVER}.textconv", command,
             %i[out err] => File::NULL)
    end

    # Reset memoized state (mainly for tests).
    def reset!
      @config = nil
      @store = nil
    end

    private

    def enrolled_in_git_diff?
      attributes = File.join(Dir.pwd, '.gitattributes')
      File.file?(attributes) &&
        File.read(attributes).include?("diff=#{GIT_DIFF_DRIVER}")
    end
  end
end

require_relative 'ironclad/railtie' if defined?(Rails::Railtie)
