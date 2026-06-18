# frozen_string_literal: true

require 'active_support/encrypted_configuration'
require_relative '../ironclad'

module Ironclad
  # Capistrano DSL helpers. Require this from your Capfile:
  #
  #   require "ironclad/capistrano"
  #
  # so deploys source RAILS_MASTER_KEY from the configured secrets manager and
  # can read credentials without a key file on disk.
  module Capistrano
    # Set RAILS_MASTER_KEY for the current stage (respecting one already set).
    def rails_master_key
      env = fetch(:rails_env, fetch(:stage)).to_s
      ENV['RAILS_MASTER_KEY'] = Ironclad.key(env)
    end

    # Read a value from the stage's encrypted credentials during a deploy.
    def credential(*keys)
      rails_master_key
      env = fetch(:rails_env, fetch(:stage)).to_s
      @ironclad_credentials ||= ActiveSupport::EncryptedConfiguration.new(
        config_path: "config/credentials/#{env}.yml.enc",
        key_path: "config/credentials/#{env}.key",
        env_key: 'RAILS_MASTER_KEY',
        raise_if_missing_key: true
      )
      @ironclad_credentials.dig(*keys) ||
        raise("Rails credential `#{keys.join('.')}` is missing")
    end
  end
end

Capistrano::DSL.include(Ironclad::Capistrano) if defined?(Capistrano::DSL)
