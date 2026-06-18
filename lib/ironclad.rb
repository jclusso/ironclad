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

    # Reset memoized state (mainly for tests).
    def reset!
      @config = nil
      @store = nil
    end
  end
end

require_relative 'ironclad/railtie' if defined?(Rails::Railtie)
